import "HybridCustody"
import "CapabilityFilter"
import "MetadataViews"
import "ShardedHybridCustodyManager"

pub contract ExampleHybridCustodyManager:  ShardedHybridCustodyManager {

    pub let ManagerManagerStoragePath: StoragePath
    pub let ManagerManagerPrivatePath: PrivatePath

    pub event ManagerManagerCreated(uuid: UInt64)
    pub event ManagerAdded(uuid: UInt64, path: String)
    pub event ManagerRemoved(uuid: UInt64, path: String)
    pub event TresholdUpdated(newTreshold: UInt64)

    pub event OwnedAccountAdded(uuid: UInt64, ownedAccount: Address)
    pub event OwnedAccountRemoved(uuid: UInt64, ownedAccount: Address)

    pub event ChildAccountAdded(uuid: UInt64, childAccount: Address)
    pub event ChildAccountRemoved(uuid: UInt64, childAccount: Address)

    pub event ContractInitialized()
    
    pub resource ManagerManager: ShardedHybridCustodyManager.ManagerManagerPrivate, ShardedHybridCustodyManager.OwnedAccountManager, ShardedHybridCustodyManager.ChildAccountManager {
        pub var MANAGER_ACCOUNT_COUNT_TRESHOLD: UInt64

        pub fun createManager(acct: &AuthAccount, filter: Capability<&{CapabilityFilter.Filter}>?) {
            let manager <- HybridCustody.createManager(filter: filter)
            self.addManager(acct: acct, manager: <- manager)
        }

        pub fun addManager(acct: &AuthAccount, manager: @HybridCustody.Manager) {
            let newManagerId = manager.uuid
            let newManagerStoragePath: StoragePath = ExampleHybridCustodyManager.getManagerStoragePath(id: newManagerId)
            let newManagerPublicPath: PublicPath = ExampleHybridCustodyManager.getManagerPublicPath(id: newManagerId)
            let newManagerPrivatePath: PrivatePath = ExampleHybridCustodyManager.getManagerPrivatePath(id: newManagerId)

            if acct.borrow<&HybridCustody.Manager>(from: newManagerStoragePath) == nil {
                acct.save(<- manager, to: newManagerStoragePath)
                acct.link<&HybridCustody.Manager{HybridCustody.ManagerPrivate, HybridCustody.ManagerPublic}>(newManagerPrivatePath, target: newManagerStoragePath)
                acct.link<&HybridCustody.Manager{HybridCustody.ManagerPublic}>(newManagerPublicPath, target: newManagerStoragePath)
            } else {
                panic("A manager already exists at: ".concat(newManagerStoragePath.toString()))
            }
            emit ManagerAdded(uuid: newManagerId, path: newManagerStoragePath.toString())
        }

        pub fun removeManager(acct: &AuthAccount, path: StoragePath): @HybridCustody.Manager? {
            return <- acct.load<@HybridCustody.Manager>(from: path)
        }

        pub fun getManager(acct: &AuthAccount, path: StoragePath): &HybridCustody.Manager? {
            return acct.borrow<&HybridCustody.Manager>(from: path)
        }

        pub fun updateManagerAccountCountTreshold(newTreshold: UInt64) {
            self.MANAGER_ACCOUNT_COUNT_TRESHOLD = newTreshold
            emit TresholdUpdated(newTreshold: newTreshold)
        }

        pub fun addOwnedAccountToManager(acct: &AuthAccount, capability: Capability<&AnyResource{HybridCustody.OwnedAccountPrivate, HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>, path: StoragePath) {
            let manager = self.getManager(acct: acct, path: path)
            if manager == nil {
                panic("Manager not found")
            }
            let managerRef = manager!
            let managerAccountCount = UInt64(managerRef.ownedAccounts.length)
            if managerAccountCount < self.MANAGER_ACCOUNT_COUNT_TRESHOLD {
                panic("Manager account count treshold reached")
            }
            managerRef.addOwnedAccount(cap: capability)
            let ownedAccountAddress = capability.borrow()?.getAddress() ?? panic ("Could not get address from capability")
            emit OwnedAccountAdded(uuid: managerRef.uuid, ownedAccount: ownedAccountAddress)
        }

        pub fun removeOwnedAccountFromManager(acct: &AuthAccount, addr: Address, path: StoragePath) {
            let manager = self.getManager(acct: acct, path: path)
            if manager == nil {
                panic("Manager not found")
            }
            let managerRef = manager!
            managerRef.removeOwned(addr: addr)
            emit OwnedAccountRemoved(uuid: managerRef.uuid, ownedAccount: addr)
        }

        pub fun addChildAccountToManager(acct: &AuthAccount, capability: Capability<&AnyResource{HybridCustody.AccountPrivate, HybridCustody.AccountPublic, MetadataViews.Resolver}>, path: StoragePath) {
            let manager = self.getManager(acct: acct, path: path)
            if manager == nil {
                panic("Manager not found")
            }
            let managerRef = manager!
            let managerAccountCount = UInt64(managerRef.childAccounts.length)
            if managerAccountCount < self.MANAGER_ACCOUNT_COUNT_TRESHOLD {
                panic("Manager account count treshold reached")
            }
            managerRef.addAccount(cap: capability)
            let childAccountAddress = capability.borrow()?.getAddress() ?? panic ("Could not get address from capability")
            emit ChildAccountAdded(uuid: managerRef.uuid, childAccount: childAccountAddress)
        }

        pub fun removeChildAccountFromManager(acct: &AuthAccount, addr: Address, path: StoragePath) {
            let manager = self.getManager(acct: acct, path: path)
            if manager == nil {
                panic("Manager not found")
            }
            let managerRef = manager!
            managerRef.removeChild(addr: addr)
            emit ChildAccountRemoved(uuid: managerRef.uuid, childAccount: addr)
        }

        init() {
            self.MANAGER_ACCOUNT_COUNT_TRESHOLD = 10_000
        }
    }

    pub fun getManagerStoragePath(id: UInt64): StoragePath {
        let managerIdentifier: String = self.getManagerIdentifier(id: id)
        return StoragePath(identifier: managerIdentifier)!
    }

    pub fun getManagerPublicPath(id: UInt64): PublicPath {
        let managerIdentifier: String = self.getManagerIdentifier(id: id)
        return PublicPath(identifier: managerIdentifier)!
    }

    pub fun getManagerPrivatePath(id: UInt64): PrivatePath {
        let managerIdentifier: String = self.getManagerIdentifier(id: id)
        return PrivatePath(identifier: managerIdentifier)!
    }

    pub fun getManagerIdentifier(id: UInt64): String {
        return "HybridCustodyManagerManager_".concat(id.toString())
    }

    pub fun createManagerManager(): @ManagerManager {
        let manager: @ManagerManager <- create ManagerManager()
        emit ManagerManagerCreated(uuid: manager.uuid)
        return <- manager
    }

    init () {
        self.ManagerManagerStoragePath = /storage/HybridCustodyManagerManagerStorage
        self.ManagerManagerPrivatePath = /private/HybridCustodyManagerManagerPrivate
    }
}

