import "CapabilityFactory"
import "NFTProviderFactory"

import "NonFungibleToken"

pub fun main(address: Address): Bool {
    
    let managerRef = getAuthAccount(address).borrow<&CapabilityFactory.Manager>(from: CapabilityFactory.StoragePath)
        ?? panic("CapabilityFactory Manager not found")
    
    let nftProviderFactory = NFTProviderFactory.Factory()

    let nftReceiverFactory = managerRef.getFactory(Type<&{NonFungibleToken.Receiver}>())

    return nftReceiverFactory != nil
}