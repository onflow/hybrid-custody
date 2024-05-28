import "CapabilityFactory"
import "FungibleToken"

access(all) contract FTAllFactory {
    access(all) struct Factory: CapabilityFactory.Factory {
        access(all) view fun getCapability(acct: auth(Capabilities) &Account, controllerID: UInt64): Capability? {
            if let con = acct.capabilities.storage.getController(byCapabilityID: controllerID) {
                if !con.capability.check<auth(FungibleToken.Withdraw) &{FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance}>() {
                    return nil
                }
                
                return con.capability as! Capability<auth(FungibleToken.Withdraw) &{FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance}>
            }

            return nil
        }

        access(all) view fun getPublicCapability(acct: &Account, path: PublicPath): Capability? {
            return nil
        }
    }
}