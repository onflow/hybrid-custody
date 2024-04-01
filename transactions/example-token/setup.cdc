import "FungibleToken"
import "ExampleToken"
import "FungibleTokenMetadataViews"

transaction {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        let md = ExampleToken.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>())! as! FungibleTokenMetadataViews.FTVaultData
        // Create a new ExampleToken Vault and put it in storage if one doesn't exist
        if acct.storage.borrow<&ExampleToken.Vault>(from: md.storagePath) == nil {
            acct.storage.save(
                <-ExampleToken.createEmptyVault(vaultType: Type<@ExampleToken.Vault>()),
                to: md.storagePath
            )
        }

        // Create a public capability to the Vault that only exposes
        // the deposit function through the Receiver interface
        acct.capabilities.unpublish(md.receiverPath)
        acct.capabilities.publish(
            acct.capabilities.storage.issue<&{FungibleToken.Receiver, FungibleToken.Balance}>(md.storagePath),
            at: md.receiverPath
        )

        // Create a public capability to the Vault that exposes the Balance and Resolver interfaces
        acct.capabilities.unpublish(md.metadataPath)
        acct.capabilities.publish(
            acct.capabilities.storage.issue<&{FungibleToken.Balance}>(md.storagePath),
            at: md.metadataPath
        )

    }
}
 