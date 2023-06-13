import "CapabilityProxy"

import "NonFungibleToken"
import "ExampleNFT"

pub fun main(address: Address): Bool {
    let proxy = getAccount(address).getCapability<&{CapabilityProxy.GetterPublic}>(CapabilityProxy.PublicPath).borrow()
        ?? panic("proxy not found")
    let publicCaps: [Capability] = proxy.getAllPublic()
    assert(publicCaps.length > 0, message: "no public capabilities found")
    
    let desiredType: Type = Type<Capability<&ExampleNFT.Collection{ExampleNFT.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic}>>()
    return publicCaps[0].getType() == desiredType
}