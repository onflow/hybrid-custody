import "HybridCustody"
import "CapabilityFilter"
import "MetadataViews"

pub contract interface ShardedHybridCustodyManager {

    /**//////////////////////////////////////////////////////////////
    //                            PATHS                            //
    /////////////////////////////////////////////////////////////**/

    pub let ManagerManagerStoragePath: StoragePath
    pub let ManagerManagerPrivatePath: PrivatePath

    /**//////////////////////////////////////////////////////////////
    //                            EVENTS                           //
    /////////////////////////////////////////////////////////////**/

    // Manager

    pub event ManagerManagerCreated(uuid: UInt64)
    pub event ManagerAdded(uuid: UInt64, path: String)
    pub event ManagerRemoved(uuid: UInt64, path: String)
    pub event TresholdUpdated(newTreshold: UInt64)

    // OwnedAccount

    pub event OwnedAccountAdded(uuid: UInt64, ownedAccount: Address)
    pub event OwnedAccountRemoved(uuid: UInt64, ownedAccount: Address)

    // ChildAccount

    pub event ChildAccountAdded(uuid: UInt64, childAccount: Address)
    pub event ChildAccountRemoved(uuid: UInt64, childAccount: Address)


    /**//////////////////////////////////////////////////////////////
    //                         INTERFACES                          //
    /////////////////////////////////////////////////////////////**/

    // Manager

    pub resource interface ManagerManagerPrivate {
        pub fun createManager(acct: &AuthAccount, filter: Capability<&{CapabilityFilter.Filter}>?)
        pub fun addManager(acct: &AuthAccount, manager: @HybridCustody.Manager)
        pub fun removeManager(acct: &AuthAccount, path: StoragePath): @HybridCustody.Manager?
        pub fun getManager(acct: &AuthAccount, path: StoragePath): &HybridCustody.Manager?
        pub fun updateManagerAccountCountTreshold(newTreshold: UInt64)
    }

    // OwnedAccount

    pub resource interface OwnedAccountManager {
        pub fun addOwnedAccountToManager(acct: &AuthAccount, capability: Capability<&AnyResource{HybridCustody.OwnedAccountPrivate, HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>, path: StoragePath) 
        pub fun removeOwnedAccountFromManager(acct: &AuthAccount, addr: Address, path: StoragePath)
    }

    // ChildAccount

    pub resource interface ChildAccountManager {
        pub fun addChildAccountToManager(acct: &AuthAccount, capability: Capability<&AnyResource{HybridCustody.AccountPrivate, HybridCustody.AccountPublic, MetadataViews.Resolver}>, path: StoragePath) 
        pub fun removeChildAccountFromManager(acct: &AuthAccount, addr: Address, path: StoragePath)
    }

    /**//////////////////////////////////////////////////////////////
    //                         RESOURCES                           //
    /////////////////////////////////////////////////////////////**/

    //  Manager Manager
    //  - Manages the creation and deletion of managers
    //  - Manages the creation and deletion of owned accounts
    //  - Manages the creation and deletion of child accounts
    //  - Treshold is the matximum number of accounts that can be managed by a manager at any given time
    //  - Treshold can be updated by the owner of the ManagerManagerPrivate Capability
    pub resource ManagerManager: ManagerManagerPrivate, ChildAccountManager, OwnedAccountManager {
        
        // Treshold is the matximum number of an account type that can be 
        // managed by a single manager resource at any given time
        pub var MANAGER_ACCOUNT_COUNT_TRESHOLD: UInt64

        // createManager
        // - Creates a new manager resource and saves it to the acct's storage
        pub fun createManager(acct: &AuthAccount, filter: Capability<&{CapabilityFilter.Filter}>?)

        // addManager
        // - Adds an existing manager to the acct's storage
        pub fun addManager(acct: &AuthAccount, manager: @HybridCustody.Manager)

        // removeManager
        // - Removes a manager from the acct's storage
        pub fun removeManager(acct: &AuthAccount, path: StoragePath): @HybridCustody.Manager? 

        // getManager
        // - Returns a reference to a manager in the acct's storage
        pub fun getManager(acct: &AuthAccount, path: StoragePath): &HybridCustody.Manager? 

        // updateManagerAccountCountTreshold
        // - Updates the treshold for the maximum number of accounts that can be managed by a manager at any given time
        pub fun updateManagerAccountCountTreshold(newTreshold: UInt64)

        // addOwnedAccountToManager
        // - Adds an owned account to a manager resource stored in the acct's storage at the given path
        pub fun addOwnedAccountToManager(acct: &AuthAccount, capability: Capability<&AnyResource{HybridCustody.OwnedAccountPrivate, HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>, path: StoragePath) 

        // removeOwnedAccountFromManager
        // - Removes an owned account from a manager resource stored in the acct's storage at the given path
        pub fun removeOwnedAccountFromManager(acct: &AuthAccount, addr: Address, path: StoragePath)

        // addChildAccountToManager
        // - Adds a child account to a manager resource stored in the acct's storage at the given path
        pub fun addChildAccountToManager(acct: &AuthAccount, capability: Capability<&AnyResource{HybridCustody.AccountPrivate, HybridCustody.AccountPublic, MetadataViews.Resolver}>, path: StoragePath)

        // removeChildAccountFromManager
        // - Removes a child account from a manager resource stored in the acct's storage at the given path
        pub fun removeChildAccountFromManager(acct: &AuthAccount, addr: Address, path: StoragePath)
    }

    /**//////////////////////////////////////////////////////////////
    //                         FUNCTIONS                           //
    /////////////////////////////////////////////////////////////**/

    // createManagerManager
    // - Creates a new ManagerManager resource
    pub fun createManagerManager(): @ManagerManager  
}

