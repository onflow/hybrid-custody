import "HybridCustody"

import "MetadataViews"
import "NonFungibleToken"
import "ExampleNFT"

transaction(parent: Address, isPublic: Bool) {
    prepare(acct: AuthAccount) {
        let o = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned account not found")
        let child: &HybridCustody.ChildAccount = o.borrowChildAccount(parent: parent)
            ?? panic("child account not found")

        let path = /private/exampleNFTFullCollection
        acct.link<&ExampleNFT.Collection>(path, target: ExampleNFT.CollectionStoragePath)
        let cap = acct.getCapability<&ExampleNFT.Collection>(path)

        o.addCapabilityToDelegator(parent: parent, cap: cap, isPublic: isPublic)
    }
}