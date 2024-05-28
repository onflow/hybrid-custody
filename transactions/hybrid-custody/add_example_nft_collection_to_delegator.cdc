import "HybridCustody"

import "MetadataViews"
import "NonFungibleToken"
import "ExampleNFT"

transaction(parent: Address, isPublic: Bool) {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        let o = acct.storage.borrow<auth(HybridCustody.Owner) &HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned account not found")
        let child: &HybridCustody.ChildAccount = o.borrowChildAccount(parent: parent)
            ?? panic("child account not found")

        let cap = acct.capabilities.storage.issue<&ExampleNFT.Collection>(ExampleNFT.CollectionStoragePath)
        o.addCapabilityToDelegator(parent: parent, cap: cap, isPublic: isPublic)
    }
}