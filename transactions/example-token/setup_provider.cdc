import "FungibleToken"
import "ExampleToken"
import "FungibleTokenMetadataViews"

transaction {
    prepare(acct: auth(Capabilities) &Account) {
        let vaultData = ExampleToken.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
            ?? panic("Could not get the vault data view for ExampleToken")
    
        acct.capabilities.storage.issue<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>(vaultData.storagePath)
    }
}
 