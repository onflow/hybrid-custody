import "FungibleToken"
import "ExampleToken"

import "FTReceiverFactory"

pub fun main(addr: Address) {
    let acct = getAuthAccount(addr)
    let ref = &acct as &AuthAccount

    let factory = FTReceiverFactory.Factory()

    let receiver = factory.getCapability(acct: ref, path: ExampleToken.ReceiverPublicPath) as! Capability<&{FungibleToken.Receiver}>
}