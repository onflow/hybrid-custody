import "CapabilityDelegator"

import "NonFungibleToken"
import "ExampleNFT"

transaction {
    prepare(acct: AuthAccount) {
        let child = acct.borrow<&CapabilityDelegator.Delegator>(from: CapabilityDelegator.StoragePath)
            ?? panic("child not found")

        let sharedCap 
            = acct.getCapability<&ExampleNFT.Collection{ExampleNFT.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)
        child.addCapability(cap: sharedCap, isPublic: true)
    }
}