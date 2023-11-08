import "CapabilityFactory"
import "NFTProviderFactory"

import "NonFungibleToken"

pub fun main(address: Address, type: Type): Bool {
    let managerRef = getAuthAccount(address).borrow<&CapabilityFactory.Manager>(
        from: CapabilityFactory.StoragePath
    ) ?? panic("CapabilityFactory Manager not found")
    
    let nftProviderFactory = NFTProviderFactory.Factory()
    
    managerRef.addFactory(type, nftProviderFactory)

    return true
}
