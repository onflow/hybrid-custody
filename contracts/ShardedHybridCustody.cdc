import "HybridCustody"
import "CapabilityFilter"

pub contract HybridCustodyManager {

    pub resource interface ManagerManagerPrivate {
        pub fun createManagerf(acct: Capability<&AuthAccount>, filter: Capability<&{CapabilityFilter.Filter}>?)
        pub fun addManager()
        pub fun removeManager(path: StoragePath)
        pub fun getManager(path: StoragePath): &HybridCustody.Manager
    }

    pub resource ManagerManager: ManagerManagerPrivate {
        pub let totalSupply: UInt64

        pub fun createManager(acct: Capability<&AuthAccount>, filter: Capability<&{CapabilityFilter.Filter}>?) {
            let newManagerPath: StoragePath = HybridCustodyManager.getManagerStoragePath(id: HybridCustodyManager.totalSupply)
            let newManager: @HybridCustody.Manager = HybridCustody.createManager(filter: filter)
            if acct.borrow<&HybridCustody.Manager>(from: newManagerPath) == nil {
                let m <- HybridCustody.createManager(filter: filter)
                acct.save(<- m, to: HybridCustody.ManagerStoragePath)
            } else {
                panic("A manager already exists at: ".concat(newManagerPath.toString()))
            }
        }

        pub fun addManager() {
          
        }

        pub fun removeManager(path: StoragePath) {
            self.manager.remove(path)
        }

        pub fun getManager(path: StoragePath): &HybridCustody.Manager {
            return &self.manager[path] as &Manager
        }

        pub fun getManagerStoragePath(id: UInt64): StoragePath {
            let managerIdentifier: String = "HybridCustodyManagerManager_".concat(id.toString())
            return StoragePath(identifier: managerIdentifier)!
        }

        init() {
            self.totalSupply = 0
        }
    }

    init () {
        
    }
}

