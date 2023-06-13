import "CapabilityProxy"

import "NonFungibleToken"
import "ExampleNFT"

pub fun main(address: Address): Bool {
    let proxy = getAuthAccount(address).getCapability<&{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>(CapabilityProxy.PrivatePath).borrow()
        ?? panic("proxy not found")

    let privateCaps: [Capability] = proxy.getAllPrivate()

    let desiredType: Type = Type<Capability<&ExampleNFT.Collection{NonFungibleToken.Provider}>>()

    return privateCaps.length == 1 && privateCaps[0].getType() == desiredType
}