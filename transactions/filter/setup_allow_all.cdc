import "CapabilityFilter"

transaction {
    prepare(acct: AuthAccount) {
        if acct.borrow<&CapabilityFilter.AllowAllFilter>(from: CapabilityFilter.StoragePath) == nil {
            acct.save(<- CapabilityFilter.create(Type<@CapabilityFilter.AllowAllFilter>()), to: CapabilityFilter.StoragePath)
        }

        acct.unlink(CapabilityFilter.PublicPath)
        let linkRes = acct.link<&CapabilityFilter.AllowAllFilter{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath, target: CapabilityFilter.StoragePath)
            ?? panic("link failed")
        assert(linkRes.check(), message: "failed to setup filter")
    }
}