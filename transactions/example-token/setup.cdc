import "FungibleToken"
import "ExampleToken"

transaction {
    prepare(acct: AuthAccount) {
        // Create a new ExampleToken Vault and put it in storage if one doesn't exist
        if acct.borrow<&ExampleToken.Vault>(from: ExampleToken.VaultStoragePath) == nil {
        acct.save(
            <-ExampleToken.createEmptyVault(),
            to: ExampleToken.VaultStoragePath
        )
        }

        // Create a public capability to the Vault that only exposes
        // the deposit function through the Receiver interface
        acct.link<&ExampleToken.Vault{FungibleToken.Receiver}>(
            ExampleToken.ReceiverPublicPath,
            target: ExampleToken.VaultStoragePath
        )

        // Create a public capability to the Vault that exposes the Balance and Resolver interfaces
        acct.link<&ExampleToken.Vault{FungibleToken.Balance}>(
            ExampleToken.VaultPublicPath,
            target: ExampleToken.VaultStoragePath
        )
    }
}
 