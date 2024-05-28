import "CapabilityFactory"
import "FungibleToken"

access(all) contract FTProviderFactory {
    access(all) struct Factory: CapabilityFactory.Factory {
        access(all) view fun getCapability(acct: auth(Capabilities) &Account, controllerID: UInt64): Capability? {
            if let con = acct.capabilities.storage.getController(byCapabilityID: controllerID) {
                if !con.capability.check<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>() {
                    return nil
                }

                return con.capability as! Capability<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>
            }

            return nil
        }

        access(all) view fun getPublicCapability(acct: &Account, path: PublicPath): Capability? {
            return nil
        }
    }
}