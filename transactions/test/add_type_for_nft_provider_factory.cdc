import "CapabilityFactory"
import "NFTProviderFactory"

import "NonFungibleToken"

transaction(type: Type) {
    prepare(account: auth(Storage) &Account) {
        let managerRef = account.storage.borrow<auth(CapabilityFactory.Add) &CapabilityFactory.Manager>(
            from: CapabilityFactory.StoragePath
        ) ?? panic("CapabilityFactory Manager not found")
    
        let nftProviderFactory = NFTProviderFactory.Factory()

        managerRef.addFactory(type, nftProviderFactory)
    }
}
