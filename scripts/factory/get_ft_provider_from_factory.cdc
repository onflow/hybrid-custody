import "FungibleToken"

import "FTProviderFactory"

pub fun main(addr: Address) {
    let acct = getAuthAccount(addr)
    let ref = &acct as &AuthAccount

    let factory = FTProviderFactory.Factory()
		let providerPath = /private/flowTokenVault

    let provider = factory.getCapability(acct: ref, path: providerPath) as! Capability<&{FungibleToken.Provider}>
}
 