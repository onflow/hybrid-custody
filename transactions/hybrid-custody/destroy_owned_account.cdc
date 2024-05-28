import "HybridCustody"
import "Burner"

transaction {
    prepare(acct: auth(Storage) &Account) {
        let m <- acct.storage.load<@AnyResource>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("no resource found in owned account storage path")
        Burner.burn(<- m)
    }
}