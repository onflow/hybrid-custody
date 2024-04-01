import "CapabilityFactory"

import "NonFungibleToken"

access(all) fun main(address: Address): [Type] {
    let getterRef = getAccount(address).capabilities.get<&{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath)!
        .borrow()
        ?? panic("CapabilityFactory Getter not found")
    return getterRef.getSupportedTypes()
}