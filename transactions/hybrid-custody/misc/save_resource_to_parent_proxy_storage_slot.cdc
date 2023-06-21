import "ExampleToken"
import "HybridCustody"

transaction(parent: Address) {
    prepare(acct: AuthAccount) {
        let v <- ExampleToken.createEmptyVault()
        let identifier = HybridCustody.getProxyAccountIdentifier(parent)
        let storagePath = StoragePath(identifier: identifier)!
        acct.save(<-v, to: storagePath)
    }
}