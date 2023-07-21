import "FungibleToken"
import "ExampleToken"

import "FTBalanceFactory"

pub fun main(addr: Address) {
    let acct = getAuthAccount(addr)
    let ref = &acct as &AuthAccount

    let factory = FTBalanceFactory.Factory()

    let provider = factory.getCapability(acct: ref, path: ExampleToken.VaultPublicPath) as! Capability<&{FungibleToken.Balance}>
}