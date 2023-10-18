import "NonFungibleToken"

import "CapabilityFactory"

pub fun main(address: Address, type: Type): Bool {
    let managerRef = getAuthAccount(address).borrow<&CapabilityFactory.Manager>(
        from: CapabilityFactory.StoragePath
    ) ?? panic("CapabilityFactory Manager not found")

    let factory = managerRef.getFactory(type)

    return factory != nil
}
