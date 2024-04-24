import "ExampleNFT"
import "MetadataViews"
import "NonFungibleToken"

import "NFTProviderFactory"

access(all) fun main(addr: Address) {
    let acct = getAuthAccount<auth(Capabilities) &Account>(addr)

    let factory = NFTProviderFactory.Factory()
    let d = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

    let controllers = acct.capabilities.storage.getControllers(forPath: d.storagePath)

    for c in controllers {
        if c.borrowType.isSubtype(of: Type<auth(NonFungibleToken.Withdraw, NonFungibleToken.Owner) &{NonFungibleToken.Provider}>()) {
            factory.getCapability(acct: acct, controllerID: c.capabilityID)! as! Capability<auth(NonFungibleToken.Withdraw, NonFungibleToken.Owner) &{NonFungibleToken.Provider}>
            return 
        }
    }

    panic("should not reach this point")
}