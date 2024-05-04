import "NonFungibleToken"
import "MetadataViews"

import "ExampleNFT"

transaction {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        let d = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

        if acct.storage.borrow<&ExampleNFT.Collection>(from: d.storagePath) == nil {
            acct.storage.save(<- ExampleNFT.createEmptyCollection(), to: ExampleNFT.CollectionStoragePath)
        }

        acct.capabilities.unpublish(d.publicPath)
        let cap = acct.capabilities.storage.issue<&{ExampleNFT.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic}>(d.storagePath)
        acct.capabilities.publish(cap, at: d.publicPath)

        acct.capabilities.storage.issue<auth(NonFungibleToken.Withdraw) &{ExampleNFT.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider}>(d.storagePath)
    }
}
