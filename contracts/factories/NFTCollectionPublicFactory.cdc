import "CapabilityFactory"
import "NonFungibleToken"

access(all) contract NFTCollectionPublicFactory {
    access(all) struct Factory: CapabilityFactory.Factory {
        access(Capabilities) view fun getCapability(acct: auth(Capabilities) &Account, controllerID: UInt64): Capability? {
            if let con = acct.capabilities.storage.getController(byCapabilityID: controllerID) {
                if !con.capability.check<&{NonFungibleToken.CollectionPublic}>() {
                    return nil
                }

                return con.capability as! Capability<&{NonFungibleToken.CollectionPublic}>
            }

            return nil
        }

        access(all) view fun getPublicCapability(acct: auth(Capabilities) &Account, path: PublicPath): Capability? {
            return acct.capabilities.get<&{NonFungibleToken.CollectionPublic}>(path)
        }
    }
}