import "CapabilityProxy"

import "NonFungibleToken"
import "ExampleNFT"

pub fun main(address: Address): Bool {
    let publicCaps: [Capability] = getAccount(address).getCapability<&{CapabilityProxy.GetterPublic}>(CapabilityProxy.PublicPath)
        .borrow()
        ?.getAllPublic()
        ?? panic("could not borrow proxy")
    
    let desiredType: Type = Type<Capability<&ExampleNFT.Collection{ExampleNFT.ExampleNFTCollectionPublic}>>()
    
    return publicCaps.length == 0 && publicCaps[0].getType() == desiredType
}