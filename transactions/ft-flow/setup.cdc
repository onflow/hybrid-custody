import "FungibleToken"

transaction {
    prepare(acct: AuthAccount) {
     let providerPath = /private/ftProvider

        acct.unlink(providerPath)
        acct.link<&{FungibleToken.Provider}>(providerPath, target: /storage/flowTokenVault)

    }
}