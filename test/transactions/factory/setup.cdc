import "CapabilityFactory"
import "NFTCollectionPublicFactory"
import "NFTProviderAndCollectionFactory"
import "NFTProviderFactory"

import "NonFungibleToken"

transaction {
    prepare(acct: AuthAccount) {
        if acct.borrow<&AnyResource>(from: CapabilityFactory.StoragePath) == nil {
            let f <- CapabilityFactory.createFactoryManager()
            acct.save(<-f, to: CapabilityFactory.StoragePath)
        }

        if !acct.getCapability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>(CapabilityFactory.PrivatePath).check() {
            acct.unlink(CapabilityFactory.PublicPath)
            acct.link<&CapabilityFactory.Manager{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath, target: CapabilityFactory.StoragePath)
        }

        assert(
            acct.getCapability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath).check(),
            message: "CapabilityFactory is not setup properly"
        )

        let manager = acct.borrow<&CapabilityFactory.Manager>(from: CapabilityFactory.StoragePath)
            ?? panic("manager not found")
        
        manager.addFactory(Type<&{NonFungibleToken.CollectionPublic}>(), NFTCollectionPublicFactory.Factory())
        manager.addFactory(Type<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(), NFTProviderAndCollectionFactory.Factory())
        manager.addFactory(Type<&{NonFungibleToken.Provider}>(), NFTProviderFactory.Factory())
    }
}
 