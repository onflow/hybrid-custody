import "FungibleToken"

import "CapabilityFactory"

pub fun main(address: Address): Bool {
    
    let managerRef = getAuthAccount(address).borrow<&CapabilityFactory.Manager>(from: CapabilityFactory.StoragePath)
        ?? panic("CapabilityFactory Manager not found")

    let balanceFactory = managerRef.getFactory(Type<&{FungibleToken.Balance}>())

    return balanceFactory != nil
}