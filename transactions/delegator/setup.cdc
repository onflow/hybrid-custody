import "CapabilityDelegator"

transaction {
    prepare(acct: AuthAccount) {
        if acct.borrow<&CapabilityDelegator.Delegator>(from: CapabilityDelegator.StoragePath) == nil {
            let delegator <- CapabilityDelegator.createDelegator()
            acct.save(<-delegator, to: CapabilityDelegator.StoragePath)
        }

        acct.unlink(CapabilityDelegator.PublicPath)
        acct.unlink(CapabilityDelegator.PrivatePath)

        acct.link<&CapabilityDelegator.Delegator{CapabilityDelegator.GetterPublic}>(CapabilityDelegator.PublicPath, target: CapabilityDelegator.StoragePath)
        acct.link<&CapabilityDelegator.Delegator{CapabilityDelegator.GetterPublic, CapabilityDelegator.GetterPrivate}>(CapabilityDelegator.PrivatePath, target: CapabilityDelegator.StoragePath)
    }
}