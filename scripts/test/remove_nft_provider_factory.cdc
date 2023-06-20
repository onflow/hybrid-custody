import "CapabilityFactory"
import "NFTProviderFactory"

import "NonFungibleToken"

pub fun main(address: Address): Bool {
    
    let managerRef = getAuthAccount(address).borrow<&CapabilityFactory.Manager>(from: CapabilityFactory.StoragePath)
        ?? panic("CapabilityFactory Manager not found")
    
    let expectedType = Type<NFTProviderFactory.Factory>()
    
    if let removed = managerRef.removeFactory(Type<&{NonFungibleToken.Provider}>()) {
        return removed.getType() == expectedType
    }

    return false
}