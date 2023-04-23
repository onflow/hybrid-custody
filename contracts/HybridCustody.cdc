import "CapabilityFactory"
import "CapabilityProxy"
import "CapabilityFilter"

pub contract HybridCustody {

    // TODO: Rename these events to start with Child
    pub let StoragePath: StoragePath
    pub let PublicPath: PublicPath
    pub let PrivatePath: PrivatePath

    pub let LinkedAccountPrivatePath: PrivatePath
    pub let BorrowableAccountPrivatePath: PrivatePath

    pub let ManagerStoragePath: StoragePath
    pub let ManagerPublicPath: PublicPath
    pub let ManagerPrivatePath: PrivatePath

    // TODO: Events!

    pub resource interface Account {
        pub fun getCapability(path: CapabilityPath, type: Type): Capability?
        pub fun getAddress(): Address
        pub fun isChildOf(_ addr: Address): Bool
        pub fun getParents(): [Address]
        pub fun borrowAccount(): &AuthAccount?
        pub fun getPublicCapability(path: PublicPath, type: Type): Capability?
    }

    pub resource interface BorrowableAccount {
        access(contract) fun borrowAccount(): &AuthAccount
    }

    pub resource interface ChildAccountPublic {
        pub fun getParents(): [Address]
        pub fun getPublicCapability(path: PublicPath, type: Type): Capability?
    }

    pub resource interface ChildAccountPrivate {
        pub fun removeParent(parent: Address): Bool
        pub fun publishToParent(
            parentAddress: Address,
            factory: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>,
            filter: Capability<&{CapabilityFilter.Filter}>
        )
        pub fun getCapability(path: CapabilityPath, type: Type): Capability?
    }

    pub resource interface AccountPublic {
        pub fun getPublicCapability(path: PublicPath, type: Type): Capability?
        access(contract) fun setRedeemed(_ addr: Address)
        pub fun getAddress(): Address
    }

    pub resource interface AccountPrivate {
        pub fun getCapability(path: CapabilityPath, type: Type): Capability?
        pub fun getPublicCapability(path: PublicPath, type: Type): Capability?
    }

    pub resource interface ManagerPrivate {
        pub fun borrowAccount(id: UInt64): &{AccountPrivate, AccountPublic}?
    }

    pub resource interface ManagerPublic {
        pub fun borrowAccountPublic(id: UInt64): &{AccountPublic}?
    }

    pub resource Manager: ManagerPrivate, ManagerPublic {
        pub let accounts: {UInt64: Capability<&{AccountPrivate, AccountPublic}>}
        pub let addressToAccountID: {Address: UInt64}

        pub let ownedAccounts: {UInt64: Capability<&{Account, ChildAccountPrivate}>}
        pub let addressToOwnedAccountID: {Address: UInt64}

        pub fun addAccount(_ cap: Capability<&{AccountPrivate, AccountPublic}>) {
            let acct = cap.borrow()
                ?? panic("invalid account capability")

            self.accounts[acct.uuid] = cap
            self.addressToAccountID[cap.address] =  acct.uuid

            // TODO: is there a scenario where you are shared the same address multiple times?
            // TODO: emit account registered event
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
        access(self) let childCap: Capability<&{BorrowableAccount}>

        pub let factory: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>
        pub let filter: Capability<&{CapabilityFilter.Filter}>
        pub let proxy: Capability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>

        pub fun getAddress(): Address {
            return self.childCap.address
        }

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
            return nil
        }

        init(
            _ childCap: Capability<&{BorrowableAccount}>,
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
            if let m = acct.borrow<&ChildAccount>(from: HybridCustody.StoragePath) {
                m.setRedeemed(addr)
            }
        }
    }

    pub resource ChildAccount: Account, BorrowableAccount, ChildAccountPublic, ChildAccountPrivate {
        pub let acct: Capability<&AuthAccount>
        pub let factory: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>
        pub let filter: Capability<&{CapabilityFilter.Filter}>
        pub let proxy: @CapabilityProxy.Proxy

        pub let parents: {Address: Bool}

        access(contract) fun setRedeemed(_ addr: Address) {
            pre {
                self.parents[addr] != nil: "address is not waiting to be redeemed"
            }

            self.parents[addr] = true
        }

        /*
        getCapability - Returns a capability from this ChildAccount's auth account,
        using its CapabilityFactory to return the right type of capability. If the desired type
        has not been registered, a nil capability will be returned.
        */
        pub fun getCapability(path: CapabilityPath, type: Type): Capability? {
            let acct = self.borrowAccount()

            let f = self.factory.borrow()!.getFactory(type)
            if f == nil {
                return nil
            }

            let cap = f!.getCapability(acct: acct, path: path)
            
            if path.getType() == Type<PrivatePath>() {
                assert(self.filter.borrow()!.allowed(cap: cap), message: "requested capability is not allowed")
            }

            return cap
        }

        pub fun getPublicCapability(path: PublicPath, type: Type): Capability? {
            let acct = self.borrowAccount()

            let f = self.factory.borrow()!.getFactory(type)
            if f == nil {
                return nil
            }

            // NOTE: we are specifically not checking the filter here because we are reading from a public path
            // which means that the capability is discoverable anyway, there's nothing we can do to prevent it from
            // being read
            return f!.getCapability(acct: acct, path: path)
        }

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

            let borrowableCap = self.borrowAccount().getCapability<&{BorrowableAccount}>(HybridCustody.PrivatePath)
            let proxyAcct <- create ProxyAccount(borrowableCap, factory, filter, proxy)
            let identifier = HybridCustody.getProxyIdentifierForParent(parentAddress)

            let s = StoragePath(identifier: identifier)!
            let p = PrivatePath(identifier: identifier)!

            acct.save(<-proxyAcct, to: s)
            acct.link<&ProxyAccount{AccountPrivate, AccountPublic}>(p, target: s)
            
            let proxyCap = acct.getCapability<&ProxyAccount{AccountPrivate, AccountPublic}>(p)
            assert(proxyCap.check(), message: "Proxy capability check failed")

            acct.inbox.publish(proxyCap, name: identifier, recipient: parentAddress)
        }

        pub fun borrowAccount(): &AuthAccount {
            return self.acct.borrow()!
        }

        pub fun getParents(): [Address] {
            return self.parents.keys
        }

        pub fun isChildOf(_ addr: Address): Bool {
            return self.parents[addr] != nil
        }

        pub fun hasRedeemed(addr: Address): Bool {
            return self.parents[addr] != nil && self.parents[addr]! == true
        }

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

        init(
            _ acct: Capability<&AuthAccount>,
            _ factory: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>,
            _ filter: Capability<&{CapabilityFilter.Filter}>,
            _ proxy: @CapabilityProxy.Proxy
        ) {
            self.acct = acct
            self.factory = factory
            self.filter = filter
            self.proxy <- proxy

            self.parents = {}
        }

        destroy () {
            destroy self.proxy
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

    pub fun createChildAccount(
        acct: Capability<&AuthAccount>,
        factory: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>,
        filter: Capability<&{CapabilityFilter.Filter}>,
        proxy: @CapabilityProxy.Proxy
    ): @ChildAccount {
        pre {
            acct.check(): "invalid auth account capability"
        }

        return <- create ChildAccount(acct, factory, filter, <-proxy)
    }

    pub fun createManager(): @Manager {
        return <- create Manager()
    }

    init() {
        let identifier = "HybridCustody".concat(self.account.address.toString())
        self.StoragePath = StoragePath(identifier: identifier)!
        self.PrivatePath = PrivatePath(identifier: identifier)!
        self.PublicPath = PublicPath(identifier: identifier)!

        self.LinkedAccountPrivatePath = PrivatePath(identifier: "LinkedAccountPrivatePath".concat(identifier))!
        self.BorrowableAccountPrivatePath = PrivatePath(identifier: "BorrowableAccountPrivatePath".concat(identifier))!

        let managerIdentifier = "HybridCustodyManager".concat(self.account.address.toString())
        self.ManagerStoragePath = StoragePath(identifier: managerIdentifier)!
        self.ManagerPublicPath = PublicPath(identifier: managerIdentifier)!
        self.ManagerPrivatePath = PrivatePath(identifier: managerIdentifier)!
    }
}
 