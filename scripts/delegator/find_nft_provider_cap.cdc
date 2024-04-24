import "CapabilityDelegator"

import "NonFungibleToken"
import "ExampleNFT"

access(all) fun main(addr: Address): Bool {
    let acct = getAuthAccount<auth(Capabilities) &Account>(addr)

    let delegator = 
        acct.capabilities.storage.issue<auth(CapabilityDelegator.Get) &{CapabilityDelegator.GetterPrivate}>(CapabilityDelegator.StoragePath).borrow()
        ?? panic("could not borrow delegator")

    let desiredType = Type<Capability<auth(NonFungibleToken.Withdraw, NonFungibleToken.Owner) &{NonFungibleToken.Provider}>>()
    let foundType = delegator.findFirstPrivateType(desiredType) ?? panic("no type found")
    
    let nakedCap = delegator.getPrivateCapability(foundType) ?? panic("requested capability type was not found")

    // we don't need to do anything with this cap, being able to cast here is enough to know
    // that this works
    let cap = nakedCap as! Capability<&{NonFungibleToken.Provider}>
    
    return true
}