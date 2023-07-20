import "CapabilityFactory"
import "NonFungibleToken"

pub contract NFTProviderFactory {
    pub struct Factory: CapabilityFactory.Factory {
        pub fun getCapability(acct: &AuthAccount, path: CapabilityPath): Capability {
            return acct.getCapability<&{NonFungibleToken.Provider}>(path)
        }

        pub fun issueCapability(acct: &AuthAccount, from: StoragePath): Capability {
            return acct.capabilities.storage.issue<&{NonFungibleToken.Provider}>(from)
        }
    }
}