import "FungibleToken"
import "ExampleToken"
import "FungibleTokenMetadataViews"

access(all) fun main(account: Address): UFix64 {
    let acct = getAccount(account)

    let vaultData = ExampleToken.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
        ?? panic("Could not get the vault data view for ExampleToken")

    let vaultRef = acct.capabilities.get<&{FungibleToken.Balance}>(vaultData.metadataPath)!.borrow()
        ?? panic("Could not borrow Balance reference to the Vault")

    return vaultRef.balance
}