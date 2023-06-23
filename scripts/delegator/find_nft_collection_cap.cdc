import "CapabilityDelegator"

import "NonFungibleToken"
import "ExampleNFT"

pub fun main(addr: Address): Bool {
    let acct = getAccount(addr)

    let delegator = 
        acct.getCapability<&CapabilityDelegator.Delegator{CapabilityDelegator.GetterPublic}>(CapabilityDelegator.PublicPath).borrow()
        ?? panic("could not borrow delegator")

    let desiredType = Type<Capability<&ExampleNFT.Collection{ExampleNFT.ExampleNFTCollectionPublic}>>()
    let foundType = delegator.findFirstPublicType(desiredType) ?? panic("no type found")
    
    let nakedCap = delegator.getPublicCapability(foundType) ?? panic("requested capability type was not found")

    // we don't need to do anything with this cap, being able to cast here is enough to know
    // that this works
    let cap = nakedCap as! Capability<&{ExampleNFT.ExampleNFTCollectionPublic}>
    
    return true
}