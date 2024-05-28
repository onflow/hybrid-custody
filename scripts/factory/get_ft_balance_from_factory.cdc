import "FungibleToken"
import "ExampleToken"
import "FungibleTokenMetadataViews"

import "FTBalanceFactory"

access(all) fun main(addr: Address) {
    let acct = getAuthAccount<auth(Capabilities) &Account>(addr)
    let factory = FTBalanceFactory.Factory()
    let vaultData = ExampleToken.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
        ?? panic("Could not get the vault data view for ExampleToken")
    factory.getPublicCapability(acct: acct, path: vaultData.metadataPath)! as! Capability<&{FungibleToken.Balance}>
}