import "HybridCustody"

import "MetadataViews"
import "NonFungibleToken"
import "ExampleNFT2"

transaction(parent: Address, isPublic: Bool) {
    prepare(acct: AuthAccount) {
        let c = acct.borrow<&HybridCustody.ChildAccount>(from: HybridCustody.ChildStoragePath)
            ?? panic("child account not found")
        let proxy = c.borrowProxyAccount(parent: parent)
            ?? panic("proxy account not found")

        let path = /private/exampleNFT2FullCollection
        acct.link<&ExampleNFT2.Collection>(path, target: ExampleNFT2.CollectionStoragePath)
        let cap = acct.getCapability<&ExampleNFT2.Collection>(path)

        c.addCapabilityToProxy(parent: parent, cap, isPublic: isPublic)
    }
}