import "CapabilityFactory"
import "NFTProviderFactory"

import "NonFungibleToken"

transaction {
    prepare(account: AuthAccount) {
        let managerRef = account.borrow<&CapabilityFactory.Manager>(from: CapabilityFactory.StoragePath)
            ?? panic("CapabilityFactory Manager not found")
    
        let nftProviderFactory = NFTProviderFactory.Factory()

        managerRef.addFactory(Type<&{NonFungibleToken.Receiver}>(), nftProviderFactory)
    }
}