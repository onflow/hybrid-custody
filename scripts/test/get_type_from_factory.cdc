import "NonFungibleToken"

import "CapabilityFactory"

access(all) fun main(address: Address, type: Type): Bool {
    let managerRef = getAuthAccount<auth(Storage) &Account>(address).storage.borrow<&CapabilityFactory.Manager>(
        from: CapabilityFactory.StoragePath
    ) ?? panic("CapabilityFactory Manager not found")

    let factory = managerRef.getFactory(type)

    return factory != nil
}
