import "FungibleToken"

import "CapabilityFactory"

pub fun main(address: Address): Bool {
    
    let managerRef = getAuthAccount(address).borrow<&CapabilityFactory.Manager>(from: CapabilityFactory.StoragePath)
        ?? panic("CapabilityFactory Manager not found")

    let receiverFactory = managerRef.getFactory(Type<&{FungibleToken.Receiver}>())

    return receiverFactory != nil
}