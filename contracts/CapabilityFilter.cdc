
/*
CapabilityFilter follows is an interface to sit ontop of a RestrictedAccount's
capabilities. Requested provider capabilities will only return if the filter's
`allowed` method returns true.
*/
pub contract CapabilityFilter {
    pub let StoragePath: StoragePath
    pub let PublicPath: PublicPath
    pub let PrivatePath: PrivatePath

    /* Events */
    //
    pub event FilterUpdated(id: UInt64, filterType: Type, type: Type, active: Bool)

    pub resource interface Filter {
        pub fun allowed(cap: Capability): Bool
        pub fun getDetails(): AnyStruct
    }

    pub resource DenylistFilter: Filter {
        // deniedTypes
        // Represents the underlying types which should not ever be 
        // returned by a RestrictedChildAccount. The filter will borrow
        // a requested capability, and make sure that the type it gets back is not
        // in the list of denied types
        access(self) let deniedTypes: {Type: Bool}

        pub fun addType(_ type: Type) {
            self.deniedTypes.insert(key: type, true)
            emit FilterUpdated(id: self.uuid, filterType: self.getType(), type: type, active: true)
        }

        pub fun removeType(_ type: Type) {
            self.deniedTypes.remove(key: type)
            emit FilterUpdated(id: self.uuid, filterType: self.getType(), type: type, active: false)
        }

        pub fun allowed(cap: Capability): Bool {
            if let item = cap.borrow<&AnyResource>() {
                return !self.deniedTypes.containsKey(item.getType())
            }

            return true
        }

        pub fun getDetails(): AnyStruct {
            return {
                "type": self.getType(),
                "deniedTypes": self.deniedTypes.keys
            }
        }

        init() {
            self.deniedTypes = {}
        }
    }

    pub resource AllowlistFilter: Filter {
        // allowedTypes
        // Represents the set of underlying types which are allowed to be 
        // returned by a RestrictedChildAccount. The filter will borrow
        // a requested capability, and make sure that the type it gets back is
        // in the list of allowed types
        access(self) let allowedTypes: {Type: Bool}

        pub fun addType(_ type: Type) {
            self.allowedTypes.insert(key: type, true)
            emit FilterUpdated(id: self.uuid, filterType: self.getType(), type: type, active: true)
        }

        pub fun removeType(_ type: Type) {
            self.allowedTypes.remove(key: type)
            emit FilterUpdated(id: self.uuid, filterType: self.getType(), type: type, active: false)
        }

        pub fun allowed(cap: Capability): Bool {
            if let item = cap.borrow<&AnyResource>() {
                return self.allowedTypes.containsKey(item.getType())
            }

            return false
        }

        pub fun getDetails(): AnyStruct {
            return {
                "type": self.getType(),
                "allowedTypes": self.allowedTypes.keys
            }
        }

        init() {
            self.allowedTypes = {}
        }
    }

    // AllowAllFilter is a passthrough, all requested capabilities are allowed
    pub resource AllowAllFilter: Filter {
        pub fun allowed(cap: Capability): Bool {
            return true
        }

        pub fun getDetails(): AnyStruct {
            return {
                "type": self.getType()
            }
        }
    }

    pub fun create(_ t: Type): @AnyResource{Filter} {
        post {
            result.getType() == t
        }

        switch t {
            case Type<@AllowAllFilter>():
                return <- create AllowAllFilter()
            case Type<@AllowlistFilter>():
                return <- create AllowlistFilter()
            case Type<@DenylistFilter>():
                return <- create DenylistFilter()
        }

        panic("unsupported type requested: ".concat(t.identifier))
    }

    init() {
        let identifier = "CapabilityFilter".concat(self.account.address.toString())
        
        self.StoragePath = StoragePath(identifier: identifier)!
        self.PublicPath = PublicPath(identifier: identifier)!
        self.PrivatePath = PrivatePath(identifier: identifier)!
    }
}
