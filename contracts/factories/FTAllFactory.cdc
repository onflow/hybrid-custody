import "CapabilityFactory"
import "FungibleToken"

pub contract FTAllFactory {
    pub struct Factory: CapabilityFactory.Factory {
        pub fun getCapability(acct: &AuthAccount, path: CapabilityPath): Capability {
            return acct.getCapability<&{FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance}>(path)
        }

        pub fun issueCapability(acct: &AuthAccount, from: StoragePath): Capability {
            return acct.capabilities.storage.issue<&{FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance}>(from)
        }
    }
}