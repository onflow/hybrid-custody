import "HybridCustody"

import "MetadataViews"
import "NonFungibleToken"
import "ExampleNFT"

transaction(parent: Address, isPublic: Bool) {
    prepare(acct: AuthAccount) {
        let c = acct.borrow<&HybridCustody.ChildAccount>(from: HybridCustody.ChildStoragePath)
            ?? panic("child account not found")
        let proxy = c.borrowProxyAccount(parent: parent)
            ?? panic("proxy account not found")

        let path = /private/exampleNFTFullCollection
        acct.link<&ExampleNFT.Collection>(path, target: ExampleNFT.CollectionStoragePath)
        let cap = acct.getCapability<&ExampleNFT.Collection>(path)

        c.addCapabilityToProxy(parent: parent, cap, isPublic: isPublic)
    }
}