import "FungibleToken"

import "CapabilityFactory"
import "FTProviderFactory"
import "FTBalanceFactory"
import "FTReceiverBalanceFactory"
import "FTReceiverFactory"
import "FTAllFactory"

transaction {
    prepare(acct: AuthAccount) {
        if acct.borrow<&AnyResource>(from: CapabilityFactory.StoragePath) == nil {
            let f <- CapabilityFactory.createFactoryManager()
            acct.save(<-f, to: CapabilityFactory.StoragePath)
        }

        if !acct.getCapability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath).check() {
            acct.unlink(CapabilityFactory.PublicPath)
            acct.link<&CapabilityFactory.Manager{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath, target: CapabilityFactory.StoragePath)
        }

        assert(
            acct.getCapability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath).check(),
            message: "CapabilityFactory is not setup properly"
        )

        let manager = acct.borrow<&CapabilityFactory.Manager>(from: CapabilityFactory.StoragePath)
            ?? panic("manager not found")

        manager.updateFactory(Type<&{FungibleToken.Provider}>(), FTProviderFactory.Factory())
        manager.updateFactory(Type<&{FungibleToken.Balance}>(), FTBalanceFactory.Factory())
        manager.updateFactory(Type<&{FungibleToken.Receiver}>(), FTReceiverFactory.Factory())
        manager.updateFactory(Type<&{FungibleToken.Receiver, FungibleToken.Balance}>(), FTReceiverBalanceFactory.Factory())
        manager.updateFactory(Type<&{FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance}>(), FTAllFactory.Factory())
    }
}
