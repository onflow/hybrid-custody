import "CapabilityFactory"
import "NFTProviderFactory"

import "NonFungibleToken"

pub fun main(address: Address) {
    
    let managerRef = getAuthAccount(address).borrow<&CapabilityFactory.Manager>(from: CapabilityFactory.StoragePath)
        ?? panic("CapabilityFactory Manager not found")
    
    let nftProviderFactory = NFTProviderFactory.Factory()
    
    managerRef.updateFactory(Type<&{NonFungibleToken.Provider}>(), nftProviderFactory)
}