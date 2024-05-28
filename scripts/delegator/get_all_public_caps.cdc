import "CapabilityDelegator"

import "NonFungibleToken"
import "ExampleNFT"

access(all) fun main(address: Address): Bool {
    let delegator = getAccount(address).capabilities.get<&{CapabilityDelegator.GetterPublic}>(CapabilityDelegator.PublicPath)!.borrow()
        ?? panic("delegator not found")
    let publicCaps: [Capability] = delegator.getAllPublic()
    assert(publicCaps.length > 0, message: "no public capabilities found")
    
    let desiredType: Type = Type<Capability<&{ExampleNFT.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic}>>()
    return publicCaps[0].getType() == desiredType
}