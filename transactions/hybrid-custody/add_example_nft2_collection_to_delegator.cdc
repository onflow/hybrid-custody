import "HybridCustody"

import "MetadataViews"
import "NonFungibleToken"
import "ExampleNFT2"

transaction(parent: Address, isPublic: Bool) {
    prepare(acct: AuthAccount) {
        let o = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned account not found")
        let child = o.borrowChildAccount(parent: parent)
            ?? panic("child account not found")

        let path = /private/exampleNFT2FullCollection
        acct.link<&ExampleNFT2.Collection>(path, target: ExampleNFT2.CollectionStoragePath)
        let cap = acct.getCapability<&ExampleNFT2.Collection>(path)

        o.addCapabilityToDelegator(parent: parent, cap: cap, isPublic: isPublic)
    }
}