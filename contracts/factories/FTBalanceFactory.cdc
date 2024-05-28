import "CapabilityFactory"
import "FungibleToken"

access(all) contract FTBalanceFactory {
    access(all) struct Factory: CapabilityFactory.Factory {
        access(all) view fun getCapability(acct: auth(Capabilities) &Account, controllerID: UInt64): Capability? {
            if let con = acct.capabilities.storage.getController(byCapabilityID: controllerID) {
                if !con.capability.check<&{FungibleToken.Balance}>() {
                    return nil
                }

                return con.capability as! Capability<&{FungibleToken.Balance}>
            }

            return nil
        }

        access(all) view fun getPublicCapability(acct: &Account, path: PublicPath): Capability? {
            return acct.capabilities.get<&{FungibleToken.Balance}>(path)
        }
    }
}