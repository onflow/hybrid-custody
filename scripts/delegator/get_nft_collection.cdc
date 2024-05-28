import "CapabilityDelegator"

import "NonFungibleToken"
import "ExampleNFT"

access(all) fun main(addr: Address): Bool {
    let acct = getAccount(addr)

    let delegator = 
        acct.capabilities.get<&{CapabilityDelegator.GetterPublic}>(CapabilityDelegator.PublicPath)!.borrow()
        ?? panic("could not borrow delegator")

    let capType = Type<Capability<&{ExampleNFT.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic}>>()
    let nakedCap = delegator.getPublicCapability(capType) ?? panic("requested capability type was not found")

    // we don't need to do anything with this cap, being able to cast here is enough to know
    // that this works
    let cap = nakedCap as! Capability<&{ExampleNFT.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic}>
    
    return true
}