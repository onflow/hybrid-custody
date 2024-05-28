import "CapabilityFilter"

transaction() {
    prepare(acct: auth(Storage) &Account) {
        let filter = acct.storage.borrow<auth(CapabilityFilter.Delete) &CapabilityFilter.AllowlistFilter>(from: CapabilityFilter.StoragePath)
            ?? panic("filter does not exist")

        filter.removeAllTypes()
    }
}
