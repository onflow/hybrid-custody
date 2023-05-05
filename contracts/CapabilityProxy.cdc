/*
CapabilityProxy is a contract used to share Capabiltities to other
accounts. It is used by the RestrictedChildAccount contract to allow
more flexible sharing of Capabilities when an app wants to share things that
aren't the NFT-standard interface types.

Inside of CapabilityProxy is a resource called Proxy which 
maintains a mapping of public and private capabilities. They cannot and should
not be mixed. A public proxy is able to be borrowed by anyone, whereas a private proxy
can only be borrowed on the RestrictedChildAccount when you have access to the full
RestrictedAccount resource.
*/
pub contract CapabilityProxy {
    pub let StoragePath: StoragePath
    pub let PrivatePath: PrivatePath
    pub let PublicPath: PublicPath
    
    /* Events */
    //
    pub event ProxyCreated(id: UInt64)
    pub event ProxyUpdated(id: UInt64, capabilityType: Type, isPublic: Bool, active: Bool)

    pub resource interface GetterPrivate {
        pub fun getPrivateCapability(_ type: Type): Capability? {
            post {
                result == nil || type.isSubtype(of: result.getType()): "incorrect returned capability type"
            }
        }

        pub fun findFirstPrivateType(_ type: Type): Type?
        pub fun getAllPrivate(): [Capability]
    }

    pub resource interface GetterPublic {
        pub fun getPublicCapability(_ type: Type): Capability? {
            post {
                result == nil || type.isSubtype(of: result.getType()): "incorrect returned capability type "
            }
        }

        pub fun findFirstPublicType(_ type: Type): Type?
        pub fun getAllPublic(): [Capability]
    }

    pub resource Proxy: GetterPublic, GetterPrivate {
        access(self) let privateCapabilities: {Type: Capability}
        access(self) let publicCapabilities: {Type: Capability}

        // ------ Begin Getter methods
        pub fun getPublicCapability(_ type: Type): Capability? {
            return self.publicCapabilities[type]
        }

        pub fun getPrivateCapability(_ type: Type): Capability? {
            return self.privateCapabilities[type]
        }

        pub fun getAllPublic(): [Capability] {
            return self.publicCapabilities.values
        }

        pub fun getAllPrivate(): [Capability] {
            return self.publicCapabilities.values
        }

        pub fun findFirstPublicType(_ type: Type): Type? {
            for t in self.publicCapabilities.keys {
                if t.isSubtype(of: type) {
                    return t
                }
            }

            return nil
        }

        pub fun findFirstPrivateType(_ type: Type): Type? {
            for t in self.privateCapabilities.keys {
                if t.isSubtype(of: type) {
                    return t
                }
            }

            return nil
        }
        // ------- End Getter methods

        pub fun addCapability(cap: Capability, isPublic: Bool) {
            if isPublic {
                self.publicCapabilities.insert(key: cap.getType(), cap)
            } else {
                self.privateCapabilities.insert(key: cap.getType(), cap)
            }
            emit ProxyUpdated(id: self.uuid, capabilityType: cap.getType(), isPublic: isPublic, active: true)
        }

        pub fun removeCapability(cap: Capability) {
            if let removedPublic = self.publicCapabilities.remove(key: cap.getType()) {
                emit ProxyUpdated(id: self.uuid, capabilityType: cap.getType(), isPublic: true, active: false)
            }
            
            if let removedPrivate = self.privateCapabilities.remove(key: cap.getType()) {
                emit ProxyUpdated(id: self.uuid, capabilityType: cap.getType(), isPublic: false, active: false)
            }
        }

        init() {
            self.privateCapabilities = {}
            self.publicCapabilities = {}
        }
    }

    pub fun createProxy(): @Proxy {
        let proxy <- create Proxy()
        emit ProxyCreated(id: proxy.uuid)
        return <- proxy
    }
    
    init() {
        let identifier = "CapabilityProxy".concat(self.account.address.toString())
        self.StoragePath = StoragePath(identifier: identifier)!
        self.PrivatePath = PrivatePath(identifier: identifier)!
        self.PublicPath = PublicPath(identifier: identifier)!
    }
}
 