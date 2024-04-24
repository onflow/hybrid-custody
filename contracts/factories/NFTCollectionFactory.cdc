import "CapabilityFactory"
import "NonFungibleToken"

access(all) contract NFTProviderAndCollectionFactory {
    access(all) struct WithdrawFactory: CapabilityFactory.Factory {
        access(all) view fun getCapability(acct: auth(Capabilities) &Account, controllerID: UInt64): Capability? {
            if let con = acct.capabilities.storage.getController(byCapabilityID: controllerID) {
                if !con.capability.check<auth(NonFungibleToken.Withdraw, NonFungibleToken.Owner) &{NonFungibleToken.Collection}>() {
                    return nil
                }

                return con.capability as! Capability<auth(NonFungibleToken.Withdraw, NonFungibleToken.Owner) &{NonFungibleToken.Collection}>
            }

            return nil
        }

        access(all) view fun getPublicCapability(acct: &Account, path: PublicPath): Capability? {
            return nil
        }
    }

    access(all) struct Factory: CapabilityFactory.Factory {
        access(all) view fun getCapability(acct: auth(Capabilities) &Account, controllerID: UInt64): Capability? {
            if let con = acct.capabilities.storage.getController(byCapabilityID: controllerID) {
                if !con.capability.check<&{NonFungibleToken.Collection}>() {
                    return nil
                }

                return con.capability as! Capability<&{NonFungibleToken.Collection}>
            }

            return nil
        }

        access(all) view fun getPublicCapability(acct: &Account, path: PublicPath): Capability? {
            if let cap = acct.capabilities.get<&{NonFungibleToken.Collection}>(path) {
                if !cap.check() {
                    return nil
                }
                
                return cap
            }

            return nil
        }
    }
}