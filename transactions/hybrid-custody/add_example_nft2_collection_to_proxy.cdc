import "HybridCustody"

import "MetadataViews"
import "NonFungibleToken"
import "ExampleNFT2"

transaction(parent: Address, isPublic: Bool) {
    prepare(acct: AuthAccount) {
        let c = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.ChildStoragePath)
            ?? panic("owned account not found")
        let child = c.borrowProxyAccount(parent: parent)
            ?? panic("child account not found")

        let path = /private/exampleNFT2FullCollection
        acct.link<&ExampleNFT2.Collection>(path, target: ExampleNFT2.CollectionStoragePath)
        let cap = acct.getCapability<&ExampleNFT2.Collection>(path)

        c.addCapabilityToProxy(parent: parent, cap: cap, isPublic: isPublic)
    }
}