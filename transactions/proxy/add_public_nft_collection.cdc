import "CapabilityProxy"

import "NonFungibleToken"
import "ExampleNFT"

transaction {
    prepare(acct: AuthAccount) {
        let child = acct.borrow<&CapabilityProxy.Proxy>(from: CapabilityProxy.StoragePath)
            ?? panic("child not found")

        let sharedCap 
            = acct.getCapability<&ExampleNFT.Collection{ExampleNFT.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)
        child.addCapability(cap: sharedCap, isPublic: true)
    }
}