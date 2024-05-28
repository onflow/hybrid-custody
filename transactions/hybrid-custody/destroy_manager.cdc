import "HybridCustody"
import "Burner"

transaction {
    prepare(acct: auth(Storage) &Account) {
        let m <- acct.storage.load<@AnyResource>(from: HybridCustody.ManagerStoragePath)
            ?? panic("no resource found in manager storage path")
        Burner.burn(<- m)
    }
}