import "CapabilityFilter"

transaction(identifier: String) {
    prepare(acct: auth(Storage) &Account) {
        let filter = acct.storage.borrow<auth(CapabilityFilter.Owner) &CapabilityFilter.DenylistFilter>(from: CapabilityFilter.StoragePath)
            ?? panic("filter does not exist")

        let c = CompositeType(identifier)!
        filter.addType(c)
    }
}