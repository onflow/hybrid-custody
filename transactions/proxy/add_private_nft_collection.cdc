import "CapabilityProxy"

import "NonFungibleToken"
import "MetadataViews"
import "ExampleNFT"

transaction {
    prepare(acct: AuthAccount) {
        let proxy = acct.borrow<&CapabilityProxy.Proxy>(from: CapabilityProxy.StoragePath)
            ?? panic("proxy not found")
        
        let d = ExampleNFT.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData
        
        let sharedCap = acct.getCapability<&ExampleNFT.Collection{NonFungibleToken.Provider}>(d.providerPath)
        
        proxy.addCapability(cap: sharedCap, isPublic: false)
    }
}