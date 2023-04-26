import "CapabilityFactory"
import "CapabilityProxy"
import "CapabilityFilter"

/*
HybridCustody defines a framework for sharing accounts via account linking. In the contract,
you will find three main resources being used:
1. ChildAccount - A resource which maintains an AuthAccount Capability, and handles publishing
    and revoking access of that account via another resource called a ProxyAccount
2. ProxyAccount - A second resource which exists on the same accounta as the ChildAccount. The ProxyAccount
    resource is the capability which is shared to a parent account. Each proxy has its own set of rules
    designating what Capability types can be retrieved, and what underlying type the capability points to can be
    given.
3. Manager - A resource setup by the parent which manages all child accounts shared with it. The Manager resource
    also maintains a set of accounts that it "owns", meaning it has a capability to the full ChildAccount resource and
    would then also be able to manage the child account's links as it sees fit.
*/
pub contract HybridCustody {

    pub let ChildStoragePath: StoragePath
    pub let ChildPublicPath: PublicPath
    pub let ChildPrivatePath: PrivatePath

    pub let ManagerStoragePath: StoragePath
    pub let ManagerPublicPath: PublicPath
    pub let ManagerPrivatePath: PrivatePath

    pub let LinkedAccountPrivatePath: PrivatePath
    pub let BorrowableAccountPrivatePath: PrivatePath

    // TODO: Events!

    // An interface which gets shared to a Manager when it is given full ownership of an account.
    pub resource interface Account {
        pub fun getAddress(): Address
        pub fun isChildOf(_ addr: Address): Bool
        pub fun getParentsAddresses(): [Address]
        pub fun borrowAccount(): &AuthAccount?
    }

    // A ChildAccount shares the BorrowableAccount capability to itelf with ProxyAccount resources
    pub resource interface BorrowableAccount {
        access(contract) fun borrowAccount(): &AuthAccount
    }

    // Public methods anyone can call on a child account
    pub resource interface ChildAccountPublic {
        pub fun getParentsAddresses(): [Address]
        pub fun getParentStatuses(): {Address: Bool}
        pub fun getRedeemedStatus(addr: Address): Bool?

        access(contract) fun setRedeemed(_ addr: Address)
    }

    // Accessible to the owner of the ChildAccount.
    pub resource interface ChildAccountPrivate {
        pub fun removeParent(parent: Address): Bool
        pub fun publishToParent(
            parentAddress: Address,
            factory: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>,
            filter: Capability<&{CapabilityFilter.Filter}>
        )
        pub fun giveOwnership(to: Address)
        pub fun relinquishOwnership()
    }

    // Public methods exposed on a proxy account resource. ChildAccountPublic will share
    // some methods here, but isn't necessarily the same
    pub resource interface AccountPublic {
        pub fun getPublicCapability(path: PublicPath, type: Type): Capability?
        pub fun getAddress(): Address
    }

    // Methods only accessible to the designated parent of a ProxyAccount
    pub resource interface AccountPrivate {
        pub fun getCapability(path: CapabilityPath, type: Type): Capability?
        pub fun getPublicCapability(path: PublicPath, type: Type): Capability?

        access(contract) fun redeemedCallback(_ addr: Address)
    }

    // Entry point for a parent to borrow its child account and obtain capabilities or
    // perform other actions on the child account
    pub resource interface ManagerPrivate {
        pub fun borrowAccount(id: UInt64): &{AccountPrivate, AccountPublic}?
        pub fun removeChildByAddress(addr: Address)
        pub fun removeChild(id: UInt64)
        pub fun removeOwnedByAddress(addr: Address)
        pub fun removeOwned(id: UInt64)
        // TODO: Owned account methods
    }

    // Functions anyone can call on a manager to get information about an account such as
    // What child accounts it has
    pub resource interface ManagerPublic {
        pub fun borrowAccountPublic(id: UInt64): &{AccountPublic}?
        // pub fun getChildAddresses(): [Address]
    }

    /*
    Manager
    A resource for an account which fills the Parent role of the Child-Parent account
    management Model. A Manager can redeem or remove child accounts, and obtain any capabilities
    exposed by the child account to them.
    */
    pub resource Manager: ManagerPrivate, ManagerPublic {
        pub let accounts: {UInt64: Capability<&{AccountPrivate, AccountPublic}>}
        pub let addressToAccountID: {Address: UInt64}

        pub let ownedAccounts: {UInt64: Capability<&{Account, ChildAccountPrivate}>}
        pub let addressToOwnedAccountID: {Address: UInt64}

        pub fun addAccount(_ cap: Capability<&{AccountPrivate, AccountPublic}>) {
            // Is there a scenario where you are shared the same address multiple times? Seems like overkill.
            let acct = cap.borrow()
                ?? panic("invalid account capability")

            self.accounts[acct.uuid] = cap
            self.addressToAccountID[cap.address] =  acct.uuid
            
            // TODO: emit account registered event

            acct.redeemedCallback(self.owner!.address)
        }

        pub fun removeChildByAddress(addr: Address) {
            let id = self.addressToAccountID.remove(key: addr)
                ?? panic("no child account found with the given address")
            self.removeChild(id: id)
        }

        pub fun removeChild(id: UInt64) {
            let cap = self.accounts.remove(key: id) ?? panic("no account found with the given id")
            self.addressToOwnedAccountID.remove(key: cap.address)

            // TODO: emit event
        }

        pub fun addOwnedAccount(_ cap: Capability<&{Account, ChildAccountPrivate}>) {
            let acct = cap.borrow()
                ?? panic("cannot add invalid account")

            self.ownedAccounts[acct.uuid] = cap
            self.addressToOwnedAccountID[cap.address] = acct.uuid
        }

        pub fun getIDs(): [UInt64] {
            return self.accounts.keys
        }

        pub fun getIDForAddress(_ addr: Address): UInt64? {
            return self.addressToAccountID[addr]
        }

        pub fun borrowAccount(id: UInt64): &{AccountPrivate, AccountPublic}? {
            let cap = self.accounts[id]
            if cap == nil {
                return nil
            }

            return cap!.borrow()
        }

        pub fun borrowAccountPublic(id: UInt64): &{AccountPublic}? {
            let cap = self.accounts[id]
            if cap == nil {
                return nil
            }

            return cap!.borrow()
        }

        pub fun borrowWithAddress(_ addr: Address): &{AccountPrivate, AccountPublic}? {
            let id = self.addressToAccountID[addr]
            if id == nil {
                return nil
            }

            return self.borrowAccount(id: id!)
        }

        pub fun removeOwnedByAddress(addr: Address) {
            let id = self.addressToOwnedAccountID[addr]
                ?? panic("no owned account with given address")
            self.removeOwned(id: id)
        }

        pub fun removeOwned(id: UInt64) {
            let acct = self.ownedAccounts.remove(key: id)
                ?? panic("account not found")
            acct.borrow()!.relinquishOwnership()

            // TODO: emit event?
        }

        pub fun giveOwnerShip(id: UInt64, to: Address) {
            let acct = self.ownedAccounts.remove(key: id)
                ?? panic("account not found")
            self.addressToOwnedAccountID.remove(key: acct.address)

            acct.borrow()!.giveOwnership(to: to)
        }

        pub fun giveOwnershipByAddress(of: Address, to: Address) {
            let id = self.addressToOwnedAccountID[of] ?? panic("account was not found")
            self.giveOwnerShip(id: id, to: to)
        }

        init() {
            self.accounts = {}
            self.addressToAccountID = {}

            self.ownedAccounts = {}
            self.addressToOwnedAccountID = {}
        }
    }

    /*
    The ProxyAccount resource sits between a child account and a parent and is stored on the same account as the child account.
    Once created, a private capability to the proxy account is shared with the intended parent. The parent account
    will accept this proxy capability into its own manager resource and use it to interact with the child account.

    Because the ProxyAccount resource exists on the child account itself, whoever owns the child account will be able to manage all
    ProxyAccount resources it shares, without worrying about whether the upstream parent can do anything to prevent it.
    */
    pub resource ProxyAccount: AccountPrivate, AccountPublic {
        access(self) let childCap: Capability<&{BorrowableAccount, ChildAccountPublic}>

        // The CapabilityFactory Manager is a ProxyAccount's way of limiting what types can be asked for
        // by its parent account. The CapabilityFactory returns Capabilities which can be
        // casted to their appropriate types once obtained, but only if the child account has configured their 
        // factory to allow it. For instance, a ProxyAccout might choose to expose NonFungibleToken.Provider, but not
        // FungibleToken.Provider
        pub let factory: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>

        // The CapabilityFilter is a restriction put at the front of obtaining any non-public Capability.
        // Some wallets might want to give access to NonFungibleToken.Provider, but only to **some** of the collections it
        // manages, not all of them.
        pub let filter: Capability<&{CapabilityFilter.Filter}>

        // The CapabilityProxy is a way to share one-off capabilities by the child account. These capabilities can be public OR private
        // and are separate from the factory which returns a capability at a given path as a certain type. When using the CapabilityProxy,
        // you do not have the ability to specify which path a capability came from. For instance, Dapper Wallet might choose to expose
        // a Capability to their Full TopShot collection, but only to the path that the collection exists in.
        pub let proxy: Capability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>

        pub fun getAddress(): Address {
            return self.childCap.address
        }

        access(contract) fun redeemedCallback(_ addr: Address) {
            self.childCap.borrow()!.setRedeemed(addr)
        }

        // The main function to get ways to access an account from a child to a parent. When a PrivatePath type is used, 
        // the CapabilityFilter will be borrowed and the Capability being returned will be checked against it to 
        // ensure that borrowing is permitted
        pub fun getCapability(path: CapabilityPath, type: Type): Capability? {
            let child = self.childCap.borrow() ?? panic("failed to borrow child account")

            let f = self.factory.borrow()!.getFactory(type)
            if f == nil {
                return nil
            }

            let acct = child.borrowAccount()

            let cap = f!.getCapability(acct: acct, path: path)
            
            if path.getType() == Type<PrivatePath>() {
                assert(self.filter.borrow()!.allowed(cap: cap), message: "requested capability is not allowed")
            }

            return cap
        }

        pub fun getPublicCapability(path: PublicPath, type: Type): Capability? {
            return self.getCapability(path: path, type: type)
        }

        init(
            _ childCap: Capability<&{BorrowableAccount, ChildAccountPublic}>,
            _ factory: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>,
            _ filter: Capability<&{CapabilityFilter.Filter}>,
            _ proxy: Capability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>
        ) {
            self.childCap = childCap
            self.factory = factory
            self.filter = filter
            self.proxy = proxy
        }

        access(contract) fun setRedeemed(_ addr: Address) {
            let acct = self.childCap.borrow()!.borrowAccount()
            if let m = acct.borrow<&ChildAccount>(from: HybridCustody.ChildStoragePath) {
                m.setRedeemed(addr)
            }
        }
    }

    /*
    ChildAccount
    A resource which sits on the account it manages to make it easier for apps to configure the behavior they want to permit.
    A ChildAccount can be used to create ProxyAccount resources and share them publish them to other addresses.

    The ChildAccount can also be used to pass ownership of an account off to another address, or to relinquish ownership entirely,
    marking the account as owned by no one. Note that even if there isn't an owner, the parent accounts would still exist, allowing
    a form of Hybrid Custody which has no true owner over an account, but shared partial ownership.
    */
    pub resource ChildAccount: Account, BorrowableAccount, ChildAccountPublic, ChildAccountPrivate {
        pub var acct: Capability<&AuthAccount>

        pub let parents: {Address: Bool}
        pub var acctOwner: Address?
        pub var relinquishedOwnership: Bool

        access(contract) fun setRedeemed(_ addr: Address) {
            pre {
                self.parents[addr] != nil: "address is not waiting to be redeemed"
            }

            self.parents[addr] = true
        }

        /*
        publishToParent
        A helper method to make it easier to manage what parents an account has configured.
        The steps to sharing this ChildAccount with a new parent are:

        1. Create a new CapabilityProxy for the ProxyAccount resource being created. We make a new one here because
           CapabilityProxy types are meant to be shared explicitly. Making one shared base-line of capabilities might
           introuce an unforseen behavior where an app accidentally shared something to all accounts when it only meant to go
           to one of them. It is better for parent accounts to have less access than they might have anticipated, than for a child
           to have given out access it did not intend to.
        2. Create a new Capability<&{BorrowableAccount}> which has its own unique path for the parent to share this child account with.
           We make new ones each time so that you can revoke access from one parent, without destroying them all. A new Link is made each time
           based on the address being shared to allow this fine-grained control, but it is all managed by the ChildAccount resource itself.
        3. A new @ProxyAccount resource is created and saved, using the CapabilityProxy made in step one, and our CapabilityFactory and CapabilityFilter
           Capabilities. Once saved, public and private links are configured for the ProxyAccount.
        4. Publish the newly made private link to the designated parent's inbox for them to claim on their @Manager resource.
        */
        pub fun publishToParent(
            parentAddress: Address,
            factory: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>,
            filter: Capability<&{CapabilityFilter.Filter}>
        ) {
            let capProxyIdentifier = HybridCustody.getCapabilityProxyIdentifierForParent(parentAddress)

            let capProxyStorage = StoragePath(identifier: capProxyIdentifier)!
            let acct = self.borrowAccount()
            if acct.borrow<&CapabilityProxy.Proxy>(from: capProxyStorage) == nil {
                let proxy <- CapabilityProxy.createProxy()
                acct.save(<-proxy, to: capProxyStorage)
            }

            let capProxyPublic = PublicPath(identifier: capProxyIdentifier)!
            let capProxyPrivate = PrivatePath(identifier: capProxyIdentifier)!

            acct.link<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic}>(capProxyPublic, target: capProxyStorage)
            acct.link<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>(capProxyPrivate, target: capProxyStorage)
            let proxy = acct.getCapability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>(capProxyPrivate)
            assert(proxy.check(), message: "failed to setup capability proxy for parent address")

            let borrowableCap = self.borrowAccount().getCapability<&{BorrowableAccount, ChildAccountPublic}>(HybridCustody.ChildPrivatePath)
            let proxyAcct <- create ProxyAccount(borrowableCap, factory, filter, proxy)
            let identifier = HybridCustody.getProxyIdentifierForParent(parentAddress)

            let s = StoragePath(identifier: identifier)!
            let p = PrivatePath(identifier: identifier)!

            acct.save(<-proxyAcct, to: s)
            acct.link<&ProxyAccount{AccountPrivate, AccountPublic}>(p, target: s)
            
            let proxyCap = acct.getCapability<&ProxyAccount{AccountPrivate, AccountPublic}>(p)
            assert(proxyCap.check(), message: "Proxy capability check failed")

            acct.inbox.publish(proxyCap, name: identifier, recipient: parentAddress)
            self.parents[parentAddress] = false
        }

        pub fun borrowAccount(): &AuthAccount {
            return self.acct.borrow()!
        }

        pub fun getParentsAddresses(): [Address] {
            return self.parents.keys
        }

        pub fun isChildOf(_ addr: Address): Bool {
            return self.parents[addr] != nil
        }

        // returns nil if the given address is not a parent, false if the parent
        // has not redeemed the child account yet, and true if they have
        pub fun getRedeemedStatus(addr: Address): Bool? {
            return self.parents[addr]
        }

        pub fun getParentStatuses(): {Address: Bool} {
            return self.parents
        }

        /*
        removeParent
        Unlinks all paths configured when publishing an account, and destroy's the @ProxyAccount resource
        configured for the provided parent address. Once done, the parent will not have any valid capabilities
        with which to access the child account.
        */
        pub fun removeParent(parent: Address): Bool {
            if self.parents[parent] == nil {
                return false
            }

            let identifier = HybridCustody.getProxyIdentifierForParent(parent)
            let capProxyIdentifier = HybridCustody.getCapabilityProxyIdentifierForParent(parent)

            let acct = self.borrowAccount()
            acct.unlink(PrivatePath(identifier: identifier)!)
            acct.unlink(PublicPath(identifier: identifier)!)

            acct.unlink(PrivatePath(identifier: capProxyIdentifier)!)
            acct.unlink(PublicPath(identifier: capProxyIdentifier)!)

            destroy <- acct.load<@AnyResource>(from: StoragePath(identifier: identifier)!)
            destroy <- acct.load<@AnyResource>(from: StoragePath(identifier: capProxyIdentifier)!)

            self.parents.remove(key: parent)

            // TODO: emit event
            return true
        }

        pub fun getAddress(): Address {
            return self.acct.address
        }

        pub fun getOwner(): Address? {
            if self.relinquishedOwnership {
                return nil
            }
            return self.acctOwner != nil ? self.acctOwner! : self.owner!.address
        }

        pub fun giveOwnership(to: Address) {
            self.relinquishOwnership()
            
            let acct = self.borrowAccount()

            let identifier =  HybridCustody.getOwnerIdentifierForParent(to)
            let cap = acct.link<&{Account, ChildAccountPrivate}>(PrivatePath(identifier: identifier)!, target: HybridCustody.ChildStoragePath)
                ?? panic("failed to link child account capability")

            acct.inbox.publish(cap, name: identifier, recipient: to)
            self.acctOwner = to
            self.relinquishedOwnership = false

            // TODO: Emit event!
        }

        // relinquishOwnership - Ensures all keys on an account are revoked, unlinks all currently active AuthAccount capabilities,
        // then makes a new one and replaces the @ChildAccount's underlying AuthAccount Capability with the new one to ensure that
        // all parent accounts can still operate normally. Unless this method is executed via the giveOwnership function, this will 
        // leave an account **without** an owner. ONLY USE WITH EXTREME CAUTION.
        pub fun relinquishOwnership() {
            // NOTE: Until Capability controllers, we can't be sure that a given auth account capability hasn't been stored and shared with
            // someone else. This means someone could "give away" ownership of an account but hide that there is a capability it has, in the event
            // that the new owner at some point adds that path back in, giving the previous owner control it wouldn't have had before.

            let acct = self.borrowAccount()

            // Revoke all keys
            acct.keys.forEach(fun (key: AccountKey): Bool {
                if !key.isRevoked {
                    acct.keys.revoke(keyIndex: key.keyIndex)
                }
                return true
            })
            
            // Find all active AuthAccount capabilities so they can be removed after we make the new auth account cap
            let pathsToUnlink: [PrivatePath] = []
            acct.forEachPrivate(fun (path: PrivatePath, type: Type): Bool {
                if type.identifier == "Capability<&AuthAccount>" {
                    pathsToUnlink.append(path)
                }
                return true
            })

            // Link a new AuthAccount Capability
            let authAcctPath = "HybridCustodyRelinquished".concat(HybridCustody.account.address.toString()).concat(getCurrentBlock().height.toString())
            let acctCap = acct.linkAccount(PrivatePath(identifier: authAcctPath)!)!

            self.acct = acctCap
            let newAcct = self.acct.borrow()!

            // cleanup, remove all previously found paths. We had to do it in this order because we will be unlinking the existing path
            // which will cause a deference issue with the originally borrowed auth account
            for  p in pathsToUnlink {
                newAcct.unlink(p)
            }
            
            self.relinquishedOwnership = true
        }

        init(
            _ acct: Capability<&AuthAccount>
        ) {
            self.acct = acct

            self.parents = {}
            self.acctOwner = nil
            self.relinquishedOwnership = false
        }
    }

    // Utility function to get the path identifier for a parent address when interacting with a 
    // child account and its parents
    pub fun getProxyIdentifierForParent(_ addr: Address): String {
        return "ProxyAccount".concat(addr.toString())
    }

    pub fun getCapabilityProxyIdentifierForParent(_ addr: Address): String {
        return "CapabilityProxy".concat(addr.toString())
    }

    pub fun getOwnerIdentifierForParent(_ addr: Address): String {
        return "HybridCustodyOwnedAccount".concat(HybridCustody.account.address.toString()).concat(addr.toString())
    }

    pub fun createChildAccount(
        acct: Capability<&AuthAccount>
    ): @ChildAccount {
        pre {
            acct.check(): "invalid auth account capability"
        }

        return <- create ChildAccount(acct)
    }

    pub fun createManager(): @Manager {
        return <- create Manager()
    }

    init() {
        let identifier = "HybridCustodyChild".concat(self.account.address.toString())
        self.ChildStoragePath = StoragePath(identifier: identifier)!
        self.ChildPrivatePath = PrivatePath(identifier: identifier)!
        self.ChildPublicPath = PublicPath(identifier: identifier)!

        self.LinkedAccountPrivatePath = PrivatePath(identifier: "LinkedAccountPrivatePath".concat(identifier))!
        self.BorrowableAccountPrivatePath = PrivatePath(identifier: "BorrowableAccountPrivatePath".concat(identifier))!

        let managerIdentifier = "HybridCustodyManager".concat(self.account.address.toString())
        self.ManagerStoragePath = StoragePath(identifier: managerIdentifier)!
        self.ManagerPublicPath = PublicPath(identifier: managerIdentifier)!
        self.ManagerPrivatePath = PrivatePath(identifier: managerIdentifier)!
    }
}
 