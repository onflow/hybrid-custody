import "CapabilityProxy"

import "NonFungibleToken"
import "ExampleNFT"

pub fun main(addr: Address): Bool {
    let acct = getAuthAccount(addr)

    let proxy = 
        acct.getCapability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPrivate}>(CapabilityProxy.PrivatePath).borrow()
        ?? panic("could not borrow proxy")

    let capType = Type<Capability<&ExampleNFT.Collection{NonFungibleToken.Provider}>>()
    let nakedCap = proxy.getPrivateCapability(capType) ?? panic("requested capability type was not found")

    // we don't need to do anything with this cap, being able to cast here is enough to know
    // that this works
    let cap = nakedCap as! Capability<&ExampleNFT.Collection{NonFungibleToken.Provider}>
    
    return true
}