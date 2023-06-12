import "CapabilityProxy"

import "NonFungibleToken"
import "ExampleNFT"

pub fun main(address: Address): Bool {
    let privateCaps: [Capability] = getAuthAccount(addr).getCapability<&CapabilityProxy.Proxy>(CapabilityProxy.PrivatePath)
        .borrow()
        ?.getAllPrivate()
        ?? panic("could not borrow proxy")

    let desiredType: Type = Type<Capability<&ExampleNFT.Collection{NonFungibleToken.Provider}>>()

    return privateCaps.length == 1 && privateCaps[0].getType() == desiredType
}