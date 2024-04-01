import "FungibleToken"

import "CapabilityFactory"
import "FTProviderFactory"
import "FTBalanceFactory"
import "FTReceiverBalanceFactory"
import "FTReceiverFactory"
import "FTAllFactory"

transaction {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        if acct.storage.borrow<&AnyResource>(from: CapabilityFactory.StoragePath) == nil {
            let f <- CapabilityFactory.createFactoryManager()
            acct.storage.save(<-f, to: CapabilityFactory.StoragePath)
        }

        if acct.capabilities.get<&{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath)?.check() != true {
            acct.capabilities.unpublish(CapabilityFactory.PublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&{CapabilityFactory.Getter}>(CapabilityFactory.StoragePath), 
                at: CapabilityFactory.PublicPath
            )
        }

        assert(
            acct.capabilities.get<&{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath)!.check(),
            message: "CapabilityFactory is not setup properly"
        )

        let manager = acct.storage.borrow<auth(Mutate) &CapabilityFactory.Manager>(from: CapabilityFactory.StoragePath)
            ?? panic("manager not found")

        manager.updateFactory(Type<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>(), FTProviderFactory.Factory())
        manager.updateFactory(Type<&{FungibleToken.Balance}>(), FTBalanceFactory.Factory())
        manager.updateFactory(Type<&{FungibleToken.Receiver}>(), FTReceiverFactory.Factory())
        manager.updateFactory(Type<&{FungibleToken.Receiver, FungibleToken.Balance}>(), FTReceiverBalanceFactory.Factory())
        manager.updateFactory(Type<auth(FungibleToken.Withdraw) &{FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance}>(), FTAllFactory.Factory())
    }
}
