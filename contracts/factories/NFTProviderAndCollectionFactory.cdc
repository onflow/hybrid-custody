import "CapabilityFactory"
import "NonFungibleToken"

access(all) contract NFTProviderAndCollectionFactory {
    access(all) struct Factory: CapabilityFactory.Factory {
        access(all) view fun getCapability(acct: auth(Capabilities) &Account, controllerID: UInt64): Capability? {
            if let con = acct.capabilities.storage.getController(byCapabilityID: controllerID) {
                if !con.capability.check<auth(NonFungibleToken.Withdraw, NonFungibleToken.Owner) &{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>() {
                    return nil
                }

                return con.capability as! Capability<auth(NonFungibleToken.Withdraw, NonFungibleToken.Owner) &{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
            }

            return nil
        }

        access(all) view fun getPublicCapability(acct: &Account, path: PublicPath): Capability? {
            return nil
        }
    }
}