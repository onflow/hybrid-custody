import "CapabilityDelegator"

import "NonFungibleToken"
import "ExampleNFT"

pub fun main(address: Address): Bool {
    let delegator = getAccount(address).getCapability<&{CapabilityDelegator.GetterPublic}>(CapabilityDelegator.PublicPath).borrow()
        ?? panic("delegator not found")
    let publicCaps: [Capability] = delegator.getAllPublic()
    assert(publicCaps.length > 0, message: "no public capabilities found")
    
    let desiredType: Type = Type<Capability<&ExampleNFT.Collection{ExampleNFT.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic}>>()
    return publicCaps[0].getType() == desiredType
}