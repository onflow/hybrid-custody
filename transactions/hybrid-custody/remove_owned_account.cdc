import "HybridCustody"

transaction(addr: Address) {
    prepare(acct: auth(Storage) &Account) {
        let m = acct.storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager not found")
        
        m.removeOwned(addr: addr)
    }
}