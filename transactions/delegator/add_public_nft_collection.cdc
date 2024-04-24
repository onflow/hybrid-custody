import "CapabilityDelegator"

import "NonFungibleToken"
import "ExampleNFT"

transaction {
    prepare(acct: auth(BorrowValue) &Account) {
        let delegator = acct.storage.borrow<auth(CapabilityDelegator.Owner) &CapabilityDelegator.Delegator>(from: CapabilityDelegator.StoragePath)
            ?? panic("delegator not found")

        let sharedCap 
            = acct.capabilities.get<&{ExampleNFT.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)!
        delegator.addCapability(cap: sharedCap, isPublic: true)
    }
}