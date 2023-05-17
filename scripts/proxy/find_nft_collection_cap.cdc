import "CapabilityProxy"

import "NonFungibleToken"
import "ExampleNFT"

pub fun main(addr: Address): Bool {
    let acct = getAccount(addr)

    let proxy = 
        acct.getCapability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic}>(CapabilityProxy.PublicPath).borrow()
        ?? panic("could not borrow proxy")

    let desiredType = Type<Capability<&ExampleNFT.Collection{ExampleNFT.ExampleNFTCollectionPublic}>>()
    let foundType = proxy.findFirstPublicType(desiredType) ?? panic("no type found")
    
    let nakedCap = proxy.getPublicCapability(foundType) ?? panic("requested capability type was not found")

    // we don't need to do anything with this cap, being able to cast here is enough to know
    // that this works
    let cap = nakedCap as! Capability<&{ExampleNFT.ExampleNFTCollectionPublic}>
    
    return true
}