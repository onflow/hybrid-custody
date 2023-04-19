import "CapabilityFilter"

transaction {
    prepare(acct: AuthAccount) {
        if acct.borrow<&CapabilityFilter.AllowlistFilter>(from: CapabilityFilter.StoragePath) == nil {
            acct.save(<-CapabilityFilter.create(Type<@CapabilityFilter.AllowlistFilter>()), to: CapabilityFilter.StoragePath)
        }

        acct.unlink(CapabilityFilter.PublicPath)
        acct.link<&CapabilityFilter.AllowlistFilter{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath, target: CapabilityFilter.StoragePath)
    }
}