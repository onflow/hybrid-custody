import "NonFungibleToken"

import "CapabilityFactory"
import "NFTCollectionPublicFactory"
import "NFTProviderAndCollectionFactory"
import "NFTProviderFactory"
import "NFTCollectionFactory"

transaction {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        if acct.storage.borrow<&AnyResource>(from: CapabilityFactory.StoragePath) == nil {
            let f <- CapabilityFactory.createFactoryManager()
            acct.storage.save(<-f, to: CapabilityFactory.StoragePath)
        }


        acct.capabilities.unpublish(CapabilityFactory.PublicPath)
        acct.capabilities.publish(
            acct.capabilities.storage.issue<&CapabilityFactory.Manager>(CapabilityFactory.StoragePath),
            at: CapabilityFactory.PublicPath
        )

        assert(
            acct.capabilities.get<&CapabilityFactory.Manager>(CapabilityFactory.PublicPath).check(),
            message: "CapabilityFactory is not setup properly"
        )

        let manager = acct.storage.borrow<auth(CapabilityFactory.Add) &CapabilityFactory.Manager>(from: CapabilityFactory.StoragePath)
            ?? panic("manager not found")

        manager.updateFactory(Type<&{NonFungibleToken.CollectionPublic}>(), NFTCollectionPublicFactory.Factory())
        manager.updateFactory(Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(), NFTProviderAndCollectionFactory.Factory())
        manager.updateFactory(Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider}>(), NFTProviderFactory.Factory())
        manager.updateFactory(Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>(), NFTCollectionFactory.WithdrawFactory())
        manager.updateFactory(Type<&{NonFungibleToken.Collection}>(), NFTCollectionFactory.Factory())
    }
}
