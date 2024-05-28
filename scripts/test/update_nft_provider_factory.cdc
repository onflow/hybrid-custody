import "CapabilityFactory"
import "NFTProviderFactory"

import "NonFungibleToken"

access(all) fun main(address: Address) {
    let managerRef = getAuthAccount<auth(Storage) &Account>(address).storage.borrow<auth(CapabilityFactory.Add) &CapabilityFactory.Manager>(from: CapabilityFactory.StoragePath)
        ?? panic("CapabilityFactory Manager not found")
    
    let nftProviderFactory = NFTProviderFactory.Factory()
    
    managerRef.updateFactory(Type<&{NonFungibleToken.Provider}>(), nftProviderFactory)
}