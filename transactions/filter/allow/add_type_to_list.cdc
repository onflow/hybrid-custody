import "CapabilityFilter"

transaction(identifier: String) {
    prepare(acct: AuthAccount) {
        let filter = acct.borrow<&CapabilityFilter.AllowlistFilter>(from: CapabilityFilter.StoragePath)
            ?? panic("filter does not exist")

        let c = CompositeType(identifier)!
        filter.addType(c)
    }
}