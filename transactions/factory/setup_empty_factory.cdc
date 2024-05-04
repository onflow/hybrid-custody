import "NonFungibleToken"
import "FungibleToken"

import "CapabilityFactory"

transaction {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        if acct.storage.borrow<&AnyResource>(from: CapabilityFactory.StoragePath) == nil {
            let f <- CapabilityFactory.createFactoryManager()
            acct.storage.save(<-f, to: CapabilityFactory.StoragePath)
        }

        if !acct.capabilities.get<&{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath).check() {
            acct.capabilities.unpublish(CapabilityFactory.PublicPath)

            let cap = acct.capabilities.storage.issue<&{CapabilityFactory.Getter}>(CapabilityFactory.StoragePath)
            acct.capabilities.publish(cap, at: CapabilityFactory.PublicPath)
        }

        assert(
            acct.capabilities.get<&{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath).check(),
            message: "CapabilityFactory is not setup properly"
        )
    }
}
