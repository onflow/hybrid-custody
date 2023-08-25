import "FungibleToken"

import "CapabilityFactory"

pub fun main(address: Address): Bool {
    
    let managerRef = getAuthAccount(address).borrow<&CapabilityFactory.Manager>(from: CapabilityFactory.StoragePath)
        ?? panic("CapabilityFactory Manager not found")

    let ftAllFactory = managerRef.getFactory(Type<&{FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance}>())

    return ftAllFactory != nil
}