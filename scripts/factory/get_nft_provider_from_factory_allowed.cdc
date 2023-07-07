import "ExampleNFT"
import "AddressUtils"
import "StringUtils"
import "MetadataViews"
import "NonFungibleToken"

import "CapabilityFilter"
import "CapabilityFactory"
import "NFTProviderFactory"

/// Determines if ExampleNFT Provider both has a Factory at the ruleAddr and is allowed by the AllowlistFilter found in
/// the ruleAddr account.
///
pub fun main(ruleAddr: Address): Bool {
    let acct = getAuthAccount(ruleAddr)
    let ref = &acct as &AuthAccount

    let factoryManager = acct.borrow<&CapabilityFactory.Manager>(from: CapabilityFactory.StoragePath)
        ?? panic("Problem borrowing CapabilityFactory Manager")
    let factory = factoryManager.getFactory(Type<&{NonFungibleToken.Provider}>())
        ?? panic("No factory for NFT Provider found")

    let d = ExampleNFT.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

    let provider = factory.getCapability(acct: ref, path: d.providerPath) as! Capability<&{NonFungibleToken.Provider}>

    let filter = acct.borrow<&CapabilityFilter.AllowlistFilter>(from: CapabilityFilter.StoragePath)
        ?? panic("Problem borrowing CapabilityFilter AllowlistFilter")
    
    return filter.allowed(cap: provider)
}