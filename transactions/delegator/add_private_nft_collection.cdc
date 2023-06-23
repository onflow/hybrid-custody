import "CapabilityDelegator"

import "NonFungibleToken"
import "MetadataViews"
import "ExampleNFT"

transaction {
    prepare(acct: AuthAccount) {
        let delegator = acct.borrow<&CapabilityDelegator.Delegator>(from: CapabilityDelegator.StoragePath)
            ?? panic("delegator not found")
        
        let d = ExampleNFT.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData
        
        let sharedCap = acct.getCapability<&ExampleNFT.Collection{NonFungibleToken.Provider}>(d.providerPath)
        
        delegator.addCapability(cap: sharedCap, isPublic: false)
    }
}