import "CapabilityFactory"

import "NonFungibleToken"

pub fun main(address: Address): [Type] {
    let getterRef = getAccount(address).getCapability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath)
        .borrow()
        ?? panic("CapabilityFactory Getter not found")
    return getterRef.getSupportedTypes()
}