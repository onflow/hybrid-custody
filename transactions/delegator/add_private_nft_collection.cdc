import "CapabilityDelegator"

import "NonFungibleToken"
import "MetadataViews"
import "ExampleNFT"

transaction {
    prepare(acct: AuthAccount) {
        let child = acct.borrow<&CapabilityDelegator.Delegator>(from: CapabilityDelegator.StoragePath)
            ?? panic("child not found")
        
        let d = ExampleNFT.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData
        
        let sharedCap = acct.getCapability<&ExampleNFT.Collection{NonFungibleToken.Provider}>(d.providerPath)
        
        child.addCapability(cap: sharedCap, isPublic: false)
    }
}