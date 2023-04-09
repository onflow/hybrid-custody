import "CapabilityProxy"

import "NonFungibleToken"
import "ExampleNFT"

transaction {
    prepare(acct: AuthAccount) {
        let proxy = acct.borrow<&CapabilityProxy.Proxy>(from: CapabilityProxy.StoragePath)
            ?? panic("proxy not found")

        let sharedCap 
            = acct.getCapability<&ExampleNFT.Collection{ExampleNFT.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)
        proxy.addCapability(cap: sharedCap, isPublic: true)
    }
}