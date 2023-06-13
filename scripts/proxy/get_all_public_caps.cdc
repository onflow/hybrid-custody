import "CapabilityProxy"

import "NonFungibleToken"
import "ExampleNFT"

pub fun main(address: Address): Bool {
    let publicCaps: [Capability] = getAccount(address).getCapability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic}>(CapabilityProxy.PublicPath)
        .borrow()
        ?.getAllPublic()
        ?? panic("could not borrow proxy")
    
    let desiredType: Type = Type<Capability<&ExampleNFT.Collection{ExampleNFT.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic}>>()
    
    return publicCaps.length == 1 && publicCaps[0].getType() == desiredType
}