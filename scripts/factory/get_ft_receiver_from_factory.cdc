import "FungibleToken"
import "ExampleToken"
import "FungibleTokenMetadataViews"

import "FTReceiverFactory"

access(all) fun main(addr: Address) {
    let acct = getAuthAccount<auth(Capabilities) &Account>(addr)

    let factory = FTReceiverFactory.Factory()

    let vaultData = ExampleToken.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
        ?? panic("Could not get the vault data view for ExampleToken")
    let controllers = acct.capabilities.storage.getControllers(forPath: vaultData.storagePath)

    for c in controllers {
        if c.borrowType.isSubtype(of: Type<&{FungibleToken.Receiver}>()) {
            factory.getCapability(acct: acct, controllerID: c.capabilityID)! as! Capability<&{FungibleToken.Receiver}>
            return 
        }
    }

    panic("should not reach this point")
}