import "CapabilityFilter"

transaction() {
    prepare(acct: AuthAccount) {
        let filter = acct.borrow<&CapabilityFilter.DenylistFilter>(from: CapabilityFilter.StoragePath)
            ?? panic("filter does not exist")

        filter.removeAllTypes()
    }
}