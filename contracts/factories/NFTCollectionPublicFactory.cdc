import "CapabilityFactory"
import "NonFungibleToken"

pub contract NFTCollectionPublicFactory {
    pub struct Factory: CapabilityFactory.Factory {
        pub fun getCapability(acct: &AuthAccount, path: CapabilityPath): Capability {
            return acct.getCapability<&{NonFungibleToken.CollectionPublic}>(path)
        }

        pub fun issueCapability(acct: &AuthAccount, from: StoragePath): Capability {
            return acct.capabilities.storage.issue<&{NonFungibleToken.CollectionPublic}>(from)
        }
    }
}