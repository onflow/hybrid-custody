import "CapabilityFilter"

transaction {
    prepare(acct: AuthAccount) {
        if acct.borrow<&CapabilityFilter.DenylistFilter>(from: CapabilityFilter.StoragePath) == nil {
            acct.save(<- CapabilityFilter.create(Type<@CapabilityFilter.DenylistFilter>()), to: CapabilityFilter.StoragePath)
        }

        acct.unlink(CapabilityFilter.PublicPath)
        acct.link<&CapabilityFilter.DenylistFilter{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath, target: CapabilityFilter.StoragePath)
    }
}