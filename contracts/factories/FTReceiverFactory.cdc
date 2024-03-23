import "CapabilityFactory"
import "FungibleToken"

access(all) contract FTReceiverFactory {
    access(all) struct Factory: CapabilityFactory.Factory {
        access(Capabilities) view fun getCapability(acct: auth(Capabilities) &Account, controllerID: UInt64): Capability? {
            if let con = acct.capabilities.storage.getController(byCapabilityID: controllerID) {
                if !con.capability.check<&{FungibleToken.Receiver}>() {
                    return nil
                }

                return con.capability as! Capability<&{FungibleToken.Receiver}>
            }

            return nil
        }
    }
}