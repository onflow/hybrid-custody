import "HybridCustody"
import "Burner"

transaction(parent: Address) {
    prepare(acct: auth(Storage) &Account) {
        let s = StoragePath(identifier: HybridCustody.getChildAccountIdentifier(parent))!
        let m <- acct.storage.load<@AnyResource>(from: s)
            ?? panic("no resource found in child account storage path")
        Burner.burn(<- m)
    }
}