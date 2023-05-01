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

Contributors (please add to this list if you contribute!):
- Austin Kline - https://twitter.com/austin_flowty
- Deniz Edincik- https://twitter.com/bluesign
- Giovanni Sanchez - https://twitter.com/gio_incognito
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

    /* Events */
    //
    pub event CreatedManager(id: UInt64)
    pub event CreatedChildAccount(id: UInt64, child: Address)
    pub event AddedProxyAccount(id: UInt64, child: Address, parent: Address)
    pub event AddedOwnedAccount(id: UInt64, child: Address, parent: Address)
    pub event RemovedProxyAccount(id: UInt64?, child: Address, parent: Address)
    pub event RemovedOwnedAccount(id: UInt64?, child: Address, parent: Address)
    pub event ProxyAccountPublished(childAcctID: UInt64, proxyAcctID: UInt64, capProxyID: UInt64, factoryID: UInt64, filterID: UInt64, filterType: Type, child: Address, pendingParent: Address) // TODO: Decide on Type or identifier String
    pub event ChildAccountRedeemed(id: UInt64, child: Address, parent: Address)
    pub event RemovedParent(id: UInt64, child: Address, parent: Address)
    pub event OwnershipGranted(id: UInt64, child: Address, owner: Address)
    pub event SealedAccount(id: UInt64, address: Address, parents: [Address])

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

        // getParentStatuses
        // Returns all parent addresses of this child account, and whether they have already
        // redeemed the parent has redeemed the account (true) or has not (false)
        pub fun getParentStatuses(): {Address: Bool}

        // getRedeemedStatus
        // Returns true if the given address is a parent of this child and has redeemed it.
        // Returns false if the given address is a parent of this child and has NOT redeemed it.
        // returns nil if the given address it not a parent of this child account.
        pub fun getRedeemedStatus(addr: Address): Bool?

        // setRedeemed
        // A callback function to mark a parent as redeemed on the child account.
        access(contract) fun setRedeemed(_ addr: Address)
    }

    // Accessible to the owner of the ChildAccount.
    pub resource interface ChildAccountPrivate {
        // removeParent
        // Deletes the proxy account resource being used to share access to this child account with the
        // supplied parent address, and unlinks the paths it was using to reach the proxy account
        pub fun removeParent(parent: Address): Bool

        // publicToParent
        // Sets up a new ProxyAccount resource for the given parentAddress to redeem.
        // This proxy account uses the supplied factory and filter to manage what can be obtained
        // from the child account, and a new CapabilityProxy resource is created for the sharing of one-off
        // capabilities. Each of these pieces of access control are managed through the child account.
        pub fun publishToParent(
            parentAddress: Address,
            factory: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>,
            filter: Capability<&{CapabilityFilter.Filter}>
        )

        // giveOwnership
        // Passes ownership of this child account to the given address. Once executed, all active keys on 
        // the child account will be revoked, and the active AuthAccount Capability being used by to obtain capabilities
        // will be rotated, preventing anyone without the newly generated capability from gaining access to the account.
        pub fun giveOwnership(to: Address)

        // seal
        // Revokes all keys on an account, unlinks all currently active AuthAccount capabilities, then makes a new one and replaces the
        // @ChildAccount's underlying AuthAccount Capability with the new one to ensure that all parent accounts can still operate normally.
        // Unless this method is executed via the giveOwnership function, this will leave an account **without** an owner.
        // USE WITH EXTREME CAUTION.
        pub fun seal()

        // setCapabilityFactoryForParent
        // Override the existing CapabilityFactory Capability for a given parent. This will allow the owner of the account
        // to start managing their own factory of capabilities to be able to retrieve
        pub fun setCapabilityFactoryForParent(parent: Address, cap: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>)

        // setCapabilityFilterForParent
        // Override the existing CapabilityFilter Capability for a given parent. This will allow the owner of the account
        // to start managing their own filter for retrieving Capabilities on Private Paths
        pub fun setCapabilityFilterForParent(parent: Address, cap: Capability<&{CapabilityFilter.Filter}>)

        // addCapabilityToProxy
        // Adds a capability to a parent's managed @ProxyAccount resource. The Capability can be made public,
        // permitting anyone to borrow it.
        pub fun addCapabilityToProxy(parent: Address, _ cap: Capability, isPublic: Bool)

        pub fun removeCapabilityFromProxy(parent: Address, _ cap: Capability)
    }

    // Public methods exposed on a proxy account resource. ChildAccountPublic will share
    // some methods here, but isn't necessarily the same
    pub resource interface AccountPublic {
        pub fun getPublicCapability(path: PublicPath, type: Type): Capability?
        pub fun getPublicCapFromProxy(type: Type): Capability?
        pub fun getAddress(): Address
    }

    // Methods only accessible to the designated parent of a ProxyAccount
    pub resource interface AccountPrivate {
        pub fun getCapability(path: CapabilityPath, type: Type): Capability? {
            post {
                result == nil || [true, nil].contains(self.getManagerCapabilityFilter()?.allowed(cap: result!)): "Capability is not allowed by this account's Parent"
            }
        }

        pub fun getPublicCapability(path: PublicPath, type: Type): Capability?
        pub fun getManagerCapabilityFilter():  &{CapabilityFilter.Filter}?
        pub fun getPrivateCapFromProxy(type: Type): Capability? {
            post {
                result == nil || [true, nil].contains(self.getManagerCapabilityFilter()?.allowed(cap: result!)): "Capability is not allowed by this account's Parent"
            }
        }

        pub fun getPublicCapFromProxy(type: Type): Capability?

        access(contract) fun redeemedCallback(_ addr: Address)
        access(contract) fun setManagerCapabilityFilter(_ managerCapabilityFilter: Capability<&{CapabilityFilter.Filter}>?)
    }

    // Entry point for a parent to borrow its child account and obtain capabilities or
    // perform other actions on the child account
    pub resource interface ManagerPrivate {
        pub fun borrowAccount(addr: Address): &{AccountPrivate, AccountPublic}?
        pub fun removeChild(addr: Address)
        pub fun removeOwned(addr: Address)

        // TODO: Owned account methods
        pub fun borrowOwnedAccount(addr: Address): &{Account, ChildAccountPublic, ChildAccountPrivate}?
        pub fun setManagerCapabilityFilter(cap: Capability<&{CapabilityFilter.Filter}>?, childAddress: Address)
    }

    // Functions anyone can call on a manager to get information about an account such as
    // What child accounts it has
    pub resource interface ManagerPublic {
        pub fun borrowAccountPublic(addr: Address): &{AccountPublic}?
        pub fun getChildAddresses(): [Address]
        pub fun getOwnedAddresses(): [Address]
        // TODO: Owned account public methods
        // TODO: What questions do we expect we should be able to ask the owner of an account? For instance
        // Should I be able to borrow typed public capabilities of an account owned by the manager?
    }

    /*
    Manager
    A resource for an account which fills the Parent role of the Child-Parent account
    management Model. A Manager can redeem or remove child accounts, and obtain any capabilities
    exposed by the child account to them.

    TODO: Implement MetadataViews.Resolver and MetadataViews.ResolverCollection
    */
    pub resource Manager: ManagerPrivate, ManagerPublic {
        pub let accounts: {Address: Capability<&{AccountPrivate, AccountPublic}>}
        pub let ownedAccounts: {Address: Capability<&{Account, ChildAccountPublic, ChildAccountPrivate}>}

        // An optional filter to gate what capabilities are permitted to be returned from a proxy account
        // For example, Dapper Wallet parent account's should not be able to retrieve any FungibleToken Provider capabilities.
        pub let filter: Capability<&{CapabilityFilter.Filter}>?

        pub fun addAccount(_ cap: Capability<&{AccountPrivate, AccountPublic}>) {
            pre {
                self.accounts[cap.address] == nil: "There is already a child account with this address"
            }

            let acct = cap.borrow()
                ?? panic("child account capability could not be borrowed")

            self.accounts[cap.address] = cap
            
            emit AddedProxyAccount(id: acct.uuid, child: cap.address, parent: self.owner!.address)

            acct.redeemedCallback(self.owner!.address)
            acct.setManagerCapabilityFilter(self.filter)
        }

        pub fun setManagerCapabilityFilter(cap: Capability<&{CapabilityFilter.Filter}>?, childAddress: Address) {
            let acct = self.borrowAccount(addr: childAddress) 
                ?? panic("child account not found")

            acct.setManagerCapabilityFilter(cap)
        }

        pub fun removeChild(addr: Address) {
            if let cap = self.accounts.remove(key: addr) {
                // TODO: Add access(contract) methods that flow down to ChildAccount s.t. parent is removed if exists in ChildAccount.parents
                let id: UInt64? = cap.borrow()?.uuid ?? nil
                emit RemovedProxyAccount(id: id, child: cap.address, parent: self.owner!.address)
            }
        }

        pub fun addOwnedAccount(_ cap: Capability<&{Account, ChildAccountPublic, ChildAccountPrivate}>) {
            pre {
                self.ownedAccounts[cap.address] == nil: "There is already a child account with this address"
            }

            let acct = cap.borrow()
                ?? panic("cannot add invalid account")
            self.ownedAccounts[cap.address] = cap

            emit AddedOwnedAccount(id: acct.uuid, child: cap.address, parent: self.owner!.address)
        }

        pub fun getAddresses(): [Address] {
            return self.accounts.keys
        }

        pub fun borrowAccount(addr: Address): &{AccountPrivate, AccountPublic}? {
            let cap = self.accounts[addr]
            if cap == nil {
                return nil
            }

            return cap!.borrow()
        }

        pub fun borrowAccountPublic(addr: Address): &{AccountPublic}? {
            let cap = self.accounts[addr]
            if cap == nil {
                return nil
            }

            return cap!.borrow()
        }

        pub fun borrowOwnedAccount(addr: Address): &{Account, ChildAccountPublic, ChildAccountPrivate}? {
            if let cap = self.ownedAccounts[addr] {
                return cap.borrow()
            }

            return nil
        }

        pub fun removeOwned(addr: Address) {
            if let acct = self.ownedAccounts.remove(key: addr) {
                if acct.check() {
                    acct.borrow()!.seal() // TODO: this should probably not fail, otherwise the owner cannot get rid of a broken link
                }
                let id: UInt64? = acct.borrow()?.uuid ?? nil
                emit RemovedOwnedAccount(id: id, child: acct.address, parent: self.owner!.address)
            }

            // Don't emit an event if nothing was removed
        }

        pub fun giveOwnerShip(addr: Address, to: Address) {
            let acct = self.ownedAccounts.remove(key: addr)
                ?? panic("account not found")
            self.ownedAccounts.remove(key: acct.address)

            acct.borrow()!.giveOwnership(to: to)
        }

        pub fun getChildAddresses(): [Address] {
            return self.accounts.keys
        }

        pub fun getOwnedAddresses(): [Address] {
            return self.ownedAccounts.keys
        }

        init(filter: Capability<&{CapabilityFilter.Filter}>?) {
            self.accounts = {}
            self.ownedAccounts = {}
            self.filter = filter
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
        pub var factory: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>

        // The CapabilityFilter is a restriction put at the front of obtaining any non-public Capability.
        // Some wallets might want to give access to NonFungibleToken.Provider, but only to **some** of the collections it
        // manages, not all of them.
        pub var filter: Capability<&{CapabilityFilter.Filter}>

        // The CapabilityProxy is a way to share one-off capabilities by the child account. These capabilities can be public OR private
        // and are separate from the factory which returns a capability at a given path as a certain type. When using the CapabilityProxy,
        // you do not have the ability to specify which path a capability came from. For instance, Dapper Wallet might choose to expose
        // a Capability to their Full TopShot collection, but only to the path that the collection exists in.
        pub let proxy: Capability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>

        // managerCapabilityFilter is a component optionally given to a proxy account when a manager redeems it. If this filter
        // is not nil, any Capability returned through the `getCapability` function checks that the manager allows access first.
        access(self) var managerCapabilityFilter: Capability<&{CapabilityFilter.Filter}>?

        pub let parent: Address

        pub fun getAddress(): Address {
            return self.childCap.address
        }

        access(contract) fun redeemedCallback(_ addr: Address) {
            self.childCap.borrow()!.setRedeemed(addr)
        }

        access(contract) fun setManagerCapabilityFilter(_ managerCapabilityFilter: Capability<&{CapabilityFilter.Filter}>?) {
            self.managerCapabilityFilter = managerCapabilityFilter
        }

        pub fun setCapabilityFactory(_ cap: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>) {
            self.factory = cap
        }

        pub fun setCapabilityFilter(_ cap: Capability<&{CapabilityFilter.Filter}>) {
            self.filter = cap
        }

        // The main function to a child account's capabilities from a parent account. When a PrivatePath type is used, 
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

        pub fun getPrivateCapFromProxy(type: Type): Capability? {
            if let p = self.proxy.borrow() {
                return p.getPrivateCapability(type)
            }

            return nil
        }

        pub fun getPublicCapFromProxy(type: Type): Capability? {
            if let p = self.proxy.borrow() {
                return p.getPublicCapability(type)
            }
            return nil
        }

        pub fun getPublicCapability(path: PublicPath, type: Type): Capability? {
            return self.getCapability(path: path, type: type)
        }

        pub fun getManagerCapabilityFilter():  &{CapabilityFilter.Filter}? {
            return self.managerCapabilityFilter != nil ? self.managerCapabilityFilter!.borrow() : nil
        }

        access(contract) fun setRedeemed(_ addr: Address) {
            let acct = self.childCap.borrow()!.borrowAccount()
            if let m = acct.borrow<&ChildAccount>(from: HybridCustody.ChildStoragePath) {
                m.setRedeemed(addr)
            }
        }

        pub fun borrowCapabilityProxy(): &CapabilityProxy.Proxy? {
            let path = HybridCustody.getCapabilityProxyIdentifier(self.parent)
            return self.childCap.borrow()!.borrowAccount().borrow<&CapabilityProxy.Proxy>(from: StoragePath(identifier: path)!)
        }

        init(
            _ childCap: Capability<&{BorrowableAccount, ChildAccountPublic}>,
            _ factory: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>,
            _ filter: Capability<&{CapabilityFilter.Filter}>,
            _ proxy: Capability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>,
            _ parent: Address
        ) {
            self.childCap = childCap
            self.factory = factory
            self.filter = filter
            self.proxy = proxy
            self.managerCapabilityFilter = nil // this will get set when a parent account redeems
            self.parent = parent
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
        priv var acct: Capability<&AuthAccount>

        pub let parents: {Address: Bool}
        pub var acctOwner: Address?
        pub var relinquishedOwnership: Bool

        access(contract) fun setRedeemed(_ addr: Address) {
            pre {
                self.parents[addr] != nil: "address is not waiting to be redeemed"
            }

            self.parents[addr] = true

            emit ChildAccountRedeemed(id: self.uuid, child: self.acct.address, parent: addr)
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
            let capProxyIdentifier = HybridCustody.getCapabilityProxyIdentifier(parentAddress)

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
            let proxyAcct <- create ProxyAccount(borrowableCap, factory, filter, proxy, parentAddress)
            emit ProxyAccountPublished(childAcctID: self.uuid, proxyAcctID: proxyAcct.uuid, capProxyID: proxy.borrow()!.uuid, factoryID: factory.borrow()!.uuid, filterID: filter.borrow()!.uuid, filterType: filter.getType(), child: self.acct.address, pendingParent: parentAddress)

            let identifier = HybridCustody.getProxyAccountIdentifier(parentAddress)
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

            let identifier = HybridCustody.getProxyAccountIdentifier(parent)
            let capProxyIdentifier = HybridCustody.getCapabilityProxyIdentifier(parent)

            let acct = self.borrowAccount()
            acct.unlink(PrivatePath(identifier: identifier)!)
            acct.unlink(PublicPath(identifier: identifier)!)

            acct.unlink(PrivatePath(identifier: capProxyIdentifier)!)
            acct.unlink(PublicPath(identifier: capProxyIdentifier)!)

            destroy <- acct.load<@AnyResource>(from: StoragePath(identifier: identifier)!)
            destroy <- acct.load<@AnyResource>(from: StoragePath(identifier: capProxyIdentifier)!)

            self.parents.remove(key: parent)
            emit RemovedParent(id: self.uuid, child: self.acct.address, parent: parent)

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
            self.seal()
            
            let acct = self.borrowAccount()

            let identifier =  HybridCustody.getOwnerIdentifier(to)
            let cap = acct.link<&{Account, ChildAccountPublic, ChildAccountPrivate}>(PrivatePath(identifier: identifier)!, target: HybridCustody.ChildStoragePath)
                ?? panic("failed to link child account capability")

            acct.inbox.publish(cap, name: identifier, recipient: to)
            self.acctOwner = to
            self.relinquishedOwnership = false

            emit OwnershipGranted(id: self.uuid, child: self.acct.address, owner: to)
        }

        // seal
        // Revokes all keys on an account, unlinks all currently active AuthAccount capabilities, then makes a new one and replaces the
        // @ChildAccount's underlying AuthAccount Capability with the new one to ensure that all parent accounts can still operate normally.
        // Unless this method is executed via the giveOwnership function, this will leave an account **without** an owner.
        // USE WITH EXTREME CAUTION.
        pub fun seal() {
            // NOTE: Until Capability controllers are released, it is possible that the owner of an account could obtain a capability to the path
            // that this method will create. Because of that, an app could fake giving ownership away fully, preventing a user from knowing that 
            // another entity has access they shouldn't have.

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
            // NOTE: This path cannot be sufficiently randomly generated, an app calling this function could build a capability to this path before
            // it is made, thus maintaining ownership despite making it look like they gave it away. Until capability controllers, this method should not be fully trusted.
            // TODO: make an additional function for the owner to rotate the auth account capability so they can mitigate this behavior (still not perfect)
            let authAcctPath = "HybridCustodyRelinquished".concat(HybridCustody.account.address.toString()).concat(getCurrentBlock().height.toString())
            let acctCap = acct.linkAccount(PrivatePath(identifier: authAcctPath)!)!

            self.acct = acctCap
            let newAcct = self.acct.borrow()!

            // cleanup, remove all previously found paths. We had to do it in this order because we will be unlinking the existing path
            // which will cause a deference issue with the originally borrowed auth account
            for  p in pathsToUnlink {
                newAcct.unlink(p)
            }

            emit SealedAccount(id: self.uuid, address: self.acct.address, parents: self.parents.keys)

            self.relinquishedOwnership = true
        }

        pub fun borrowProxyAccount(parent: Address): &ProxyAccount? {
            let identifier = HybridCustody.getProxyAccountIdentifier(parent)
            return self.borrowAccount().borrow<&ProxyAccount>(from: StoragePath(identifier: identifier)!)
        }

        pub fun setCapabilityFactoryForParent(parent: Address, cap: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>) {
            let p = self.borrowProxyAccount(parent: parent) ?? panic("could not find parent address")
            p.setCapabilityFactory(cap)
        }

        pub fun setCapabilityFilterForParent(parent: Address, cap: Capability<&{CapabilityFilter.Filter}>) {
            let p = self.borrowProxyAccount(parent: parent) ?? panic("could not find parent address")
            p.setCapabilityFilter(cap)
        }

        pub fun borrowCapabilityProxyForParent(parent: Address): &CapabilityProxy.Proxy? {
            let identifier = HybridCustody.getCapabilityProxyIdentifier(parent)
            return self.borrowAccount().borrow<&CapabilityProxy.Proxy>(from: StoragePath(identifier: identifier)!)
        }

        pub fun addCapabilityToProxy(parent: Address, _ cap: Capability, isPublic: Bool) {
            let p = self.borrowProxyAccount(parent: parent) ?? panic("could not find parent address")
            let proxy = self.borrowCapabilityProxyForParent(parent: parent) ?? panic("could not borrow capability proxy resource for parent address")
            proxy.addCapability(cap: cap, isPublic: isPublic)
        }

        pub fun removeCapabilityFromProxy(parent: Address, _ cap: Capability) {
            let p = self.borrowProxyAccount(parent: parent) ?? panic("could not find parent address")
            let proxy = self.borrowCapabilityProxyForParent(parent: parent) ?? panic("could not borrow capability proxy resource for parent address")
            proxy.removeCapability(cap: cap)
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
    pub fun getProxyAccountIdentifier(_ addr: Address): String {
        return "ProxyAccount".concat(addr.toString())
    }

    pub fun getCapabilityProxyIdentifier(_ addr: Address): String {
        return "ChildCapabilityProxy".concat(addr.toString())
    }

    pub fun getOwnerIdentifier(_ addr: Address): String {
        return "HybridCustodyOwnedAccount".concat(HybridCustody.account.address.toString()).concat(addr.toString())
    }

    pub fun createChildAccount(
        acct: Capability<&AuthAccount>
    ): @ChildAccount {
        pre {
            acct.check(): "invalid auth account capability"
        }

        let childAcct <- create ChildAccount(acct)
        emit CreatedChildAccount(id: childAcct.uuid, child: acct.borrow()!.address)
        return <- childAcct
    }

    pub fun createManager(filter: Capability<&{CapabilityFilter.Filter}>?): @Manager {
        let manager <- create Manager(filter: filter)
        emit CreatedManager(id: manager.uuid)
        return <- manager
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
 