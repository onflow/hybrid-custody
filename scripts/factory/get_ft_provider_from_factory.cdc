import "FungibleToken"
import "ExampleToken"
import "FungibleTokenMetadataViews"

import "FTProviderFactory"

access(all) fun main(addr: Address) {
    let acct = getAuthAccount<auth(Capabilities) &Account>(addr)
    let factory = FTProviderFactory.Factory()

    let vaultData = ExampleToken.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
        ?? panic("Could not get the vault data view for ExampleToken")

    acct.capabilities.storage.issue<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>(vaultData.storagePath)

    let controllers = acct.capabilities.storage.getControllers(forPath: vaultData.storagePath)
    for c in controllers {
        if c.borrowType.isSubtype(of: Type<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>()) {
            factory.getCapability(acct: acct, controllerID: c.capabilityID)! as! Capability<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>
            return 
        }
    }

    panic("should not reach this point")
}