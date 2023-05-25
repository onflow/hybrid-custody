import "FungibleToken"
import "ExampleToken"

transaction {
    prepare(acct: AuthAccount) {
    // Create Provider capability that can be used by parent to access the child's vault and transfer tokens
     let providerPath = /private/exampleTokenProvider

        acct.unlink(providerPath)
        acct.link<&{FungibleToken.Provider}>(providerPath, target: ExampleToken.VaultStoragePath)
    }
}
 