import "CapabilityDelegator"

import "NonFungibleToken"
import "ExampleNFT"

pub fun main(addr: Address): Bool {
    let acct = getAuthAccount(addr)

    let delegator = 
        acct.getCapability<&CapabilityDelegator.Delegator{CapabilityDelegator.GetterPrivate}>(CapabilityDelegator.PrivatePath).borrow()
        ?? panic("could not borrow delegator")

    let desiredType = Type<Capability<&ExampleNFT.Collection{NonFungibleToken.Provider}>>()
    let foundType = delegator.findFirstPrivateType(desiredType) ?? panic("no type found")
    
    let nakedCap = delegator.getPrivateCapability(foundType) ?? panic("requested capability type was not found")

    // we don't need to do anything with this cap, being able to cast here is enough to know
    // that this works
    let cap = nakedCap as! Capability<&{NonFungibleToken.Provider}>
    
    return true
}