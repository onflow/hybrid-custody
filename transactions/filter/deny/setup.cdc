import "CapabilityFilter"

transaction {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        if acct.storage.borrow<&AnyResource>(from: CapabilityFilter.StoragePath) == nil {
            acct.storage.save(<- CapabilityFilter.createFilter(Type<@CapabilityFilter.DenylistFilter>()), to: CapabilityFilter.StoragePath)
        }

        acct.capabilities.unpublish(CapabilityFilter.PublicPath)
        acct.capabilities.publish(
            acct.capabilities.storage.issue<&{CapabilityFilter.Filter}>(CapabilityFilter.StoragePath),
            at: CapabilityFilter.PublicPath
        )

        assert(acct.capabilities.get<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)?.check() == true, message: "failed to setup filter")
    }
}