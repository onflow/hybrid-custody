import "CapabilityFactory"
import "FungibleToken"

access(all) contract FTVaultFactory {
    access(all) struct WithdrawFactory: CapabilityFactory.Factory {
        access(all) view fun getCapability(acct: auth(Capabilities) &Account, controllerID: UInt64): Capability? {
            if let con = acct.capabilities.storage.getController(byCapabilityID: controllerID) {
                if !con.capability.check<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>() {
                    return nil
                }
                
                return con.capability as! Capability<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>
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
                if !con.capability.check<&{FungibleToken.Vault}>() {
                    return nil
                }
                
                return con.capability as! Capability<&{FungibleToken.Vault}>
            }

            return nil
        }

        access(all) view fun getPublicCapability(acct: &Account, path: PublicPath): Capability? {
            let cap = acct.capabilities.get<&{FungibleToken.Vault}>(path)
            if !cap.check() {
                return nil
            }
                
            return cap

        }
    }
}