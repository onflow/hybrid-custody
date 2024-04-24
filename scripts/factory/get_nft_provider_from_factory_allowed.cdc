import "ExampleNFT"
import "MetadataViews"
import "NonFungibleToken"

import "CapabilityFilter"
import "CapabilityFactory"
import "NFTProviderFactory"

/// Determines if ExampleNFT Provider both has a Factory at the ruleAddr and is allowed by the AllowlistFilter found in
/// the ruleAddr account.
///
access(all) fun main(filterFactoryAddr: Address, providerAddr: Address): Bool {
    let ruleAcct = getAuthAccount<auth(Storage, Capabilities) &Account>(filterFactoryAddr)
    let providerAcct = getAuthAccount<auth(Storage, Capabilities) &Account>(providerAddr)

    let factoryManager = ruleAcct.storage.borrow<&CapabilityFactory.Manager>(from: CapabilityFactory.StoragePath)
        ?? panic("Problem borrowing CapabilityFactory Manager")
    let factory = factoryManager.getFactory(Type<auth(NonFungibleToken.Withdraw, NonFungibleToken.Owner) &{NonFungibleToken.Provider}>())
        ?? panic("No factory for NFT Provider found")

    let d = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

    var controllerID: UInt64? = nil
    for c in providerAcct.capabilities.storage.getControllers(forPath: d.storagePath) {
        if c.borrowType.isSubtype(of: Type<auth(NonFungibleToken.Withdraw, NonFungibleToken.Owner) &{NonFungibleToken.Provider}>()) {
            controllerID = c.capabilityID
            break
        }
    }

    assert(controllerID != nil, message: "could not find existing provider capcon")

    let provider = factory.getCapability(acct: providerAcct, controllerID: controllerID!)! as! Capability<auth(NonFungibleToken.Withdraw, NonFungibleToken.Owner) &{NonFungibleToken.Provider}>

    let filter = ruleAcct.storage.borrow<&CapabilityFilter.AllowlistFilter>(from: CapabilityFilter.StoragePath)
        ?? panic("Problem borrowing CapabilityFilter AllowlistFilter")
    
    return filter.allowed(cap: provider)
}