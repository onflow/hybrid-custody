import "CapabilityFactory"
import "NFTProviderFactory"

import "NonFungibleToken"

pub fun main(address: Address): Bool {
    
    let managerRef = getAuthAccount(address).borrow<&CapabilityFactory.Manager>(from: CapabilityFactory.StoragePath)
        ?? panic("CapabilityFactory Manager not found")
    
    let nftProviderFactory = NFTProviderFactory.Factory()
    
    managerRef.addFactory(Type<&{NonFungibleToken.Provider}>(), nftProviderFactory)

    return true
}