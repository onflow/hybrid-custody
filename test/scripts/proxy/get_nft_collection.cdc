import "CapabilityProxy"

import "NonFungibleToken"
import "ExampleNFT"

pub fun main(addr: Address): Bool {
    let acct = getAccount(addr)

    let proxy = 
        acct.getCapability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic}>(CapabilityProxy.PublicPath).borrow()
        ?? panic("could not borrow proxy")

    let capType = Type<Capability<&ExampleNFT.Collection{ExampleNFT.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic}>>()
    let nakedCap = proxy.getPublicCapability(capType) ?? panic("requested capability type was not found")

    // we don't need to do anything with this cap, being able to cast here is enough to know
    // that this works
    let cap = nakedCap as! Capability<&ExampleNFT.Collection{ExampleNFT.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic}>
    
    return true
}