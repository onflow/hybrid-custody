import "CapabilityDelegator"

transaction {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        if acct.storage.borrow<&CapabilityDelegator.Delegator>(from: CapabilityDelegator.StoragePath) == nil {
            let delegator <- CapabilityDelegator.createDelegator()
            acct.storage.save(<-delegator, to: CapabilityDelegator.StoragePath)
        }

        acct.capabilities.unpublish(CapabilityDelegator.PublicPath)

        let cap = acct.capabilities.storage.issue<&{CapabilityDelegator.GetterPublic}>(CapabilityDelegator.StoragePath)
        acct.capabilities.publish(cap, at: CapabilityDelegator.PublicPath)
    }
}