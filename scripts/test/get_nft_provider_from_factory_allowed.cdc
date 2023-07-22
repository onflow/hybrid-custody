import "MetadataViews"
import "NonFungibleToken"

import "CapabilityFilter"
import "CapabilityFactory"
import "NFTProviderFactory"

/// Determines if ExampleNFT Provider both has a Factory at the ruleAddr and is allowed by the AllowlistFilter found in
/// the ruleAddr account.
///
pub fun main(filterFactoryAddr: Address, providerAddr: Address, providerPathIdentifier: String): Bool {
    let ruleAcct = getAuthAccount(filterFactoryAddr)
    let providerAcct = &getAuthAccount(providerAddr) as! &AuthAccount

    let factoryManager = ruleAcct.borrow<&CapabilityFactory.Manager>(from: CapabilityFactory.StoragePath)
        ?? panic("Problem borrowing CapabilityFactory Manager")
    let factory = factoryManager.getFactory(Type<&{NonFungibleToken.Provider}>())
        ?? panic("No factory for NFT Provider found")

    let providerPath = CapabilityPath(identifier: providerPathIdentifier) ?? panic("Invalid identifier provided!")
    let provider = factory.getCapability(acct: providerAcct, path: providerPath) as! Capability<&{NonFungibleToken.Provider}>

    let filter = ruleAcct.borrow<&CapabilityFilter.AllowlistFilter>(from: CapabilityFilter.StoragePath)
        ?? panic("Problem borrowing CapabilityFilter AllowlistFilter")
    
    return filter.allowed(cap: provider)
}