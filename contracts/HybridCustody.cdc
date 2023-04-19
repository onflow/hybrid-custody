import "CapabilityFactory"
import "CapabilityProxy"
import "CapabilityFilter"

pub contract HybridCustody {
    pub let StoragePath: StoragePath
    pub let PublicPath: PublicPath
    pub let PrivatePath: PrivatePath

    pub let LinkedAccountPrivatePath: PrivatePath

    pub resource interface Account {
        pub fun getCapability(path: CapabilityPath, type: Type): Capability?
        // pub fun getAddress(): Address
        // pub fun isChildOf(_ addr: Address)
        // pub fun getParents(): [Address]
        // pub fun canBorrowAcct(): Bool
        // pub fun borrowAcct(): &AuthAccount?
        // pub fun publishToParent(parent: Address)
        // pub fun getPublicCapability(path: PublicPath, type: Type): Capability?
    }

    pub resource interface AccountPublic {
        pub fun getPublicCapability(path: PublicPath, type: Type): Capability?
    }

    pub resource interface AccountPrivate {
        pub fun getCapability(path: CapabilityPath, type: Type): Capability?
    }

    pub resource ChildAccount: Account, AccountPrivate, AccountPublic {
        pub let acct: Capability<&AuthAccount>
        pub let factory: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>
        pub let filter: Capability<&{CapabilityFilter.Filter}>
        pub let proxy: @CapabilityProxy.Proxy

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
            return self.getCapability(path: path, type: type)
        }

        pub fun borrowAccount(): &AuthAccount {
            return self.acct.borrow()!
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
        }

        destroy () {
            destroy self.proxy
        }
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

    init() {
        let identifier = "HybridCustody".concat(self.account.address.toString())
        self.StoragePath = StoragePath(identifier: identifier)!
        self.PrivatePath = PrivatePath(identifier: identifier)!
        self.PublicPath = PublicPath(identifier: identifier)!

        self.LinkedAccountPrivatePath = PrivatePath(identifier: "LinkedAccountPrivatePath".concat(identifier))!
    }
}
 