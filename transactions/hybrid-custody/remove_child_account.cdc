import "HybridCustody"

transaction(child: Address) {
    prepare (acct: auth(Storage) &Account) {
        let manager = acct.storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager not found")
        manager.removeChild(addr: child)
    }
}