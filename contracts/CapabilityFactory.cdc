pub contract CapabilityFactory {
    pub let StoragePath: StoragePath
    pub let PrivatePath: PrivatePath
    pub let PublicPath: PublicPath
    
    pub struct interface Factory {
        pub fun getCapability(acct: &AuthAccount, path: CapabilityPath): Capability
    }

    pub resource interface Getter {
        pub fun getFactory(_ t: Type): {CapabilityFactory.Factory}?
    }

    pub resource Manager: Getter {
        pub let factories: {Type: {CapabilityFactory.Factory}}

        pub fun addFactory(_ t: Type, _ f: {CapabilityFactory.Factory}) {
            self.factories[t] = f
        }

        pub fun getFactory(_ t: Type): {CapabilityFactory.Factory}? {
            return self.factories[t]
        }

        init () {
            self.factories = {}
        }
    }

    pub fun createFactoryManager(): @Manager {
        return <- create Manager()
    }

    init() {
        let identifier = "CapabilityFactory".concat(self.account.address.toString())
        self.StoragePath = StoragePath(identifier: identifier)!
        self.PrivatePath = PrivatePath(identifier: identifier)!
        self.PublicPath = PublicPath(identifier: identifier)!
    }
}