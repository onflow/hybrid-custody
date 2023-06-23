import "CapabilityDelegator"

import "NonFungibleToken"
import "ExampleNFT"

pub fun main(address: Address): Bool {
    let privateCaps: [Capability] = getAuthAccount(address).getCapability<&CapabilityDelegator.Delegator{CapabilityDelegator.GetterPrivate}>(CapabilityDelegator.PrivatePath)
        .borrow()
        ?.getAllPrivate()
        ?? panic("could not borrow delegator")

    let desiredType: Type = Type<Capability<&ExampleNFT.Collection{NonFungibleToken.Provider}>>()

    return privateCaps.length == 1 && privateCaps[0].getType() == desiredType
}