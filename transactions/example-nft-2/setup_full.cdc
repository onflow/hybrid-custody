import "NonFungibleToken"
import "MetadataViews"

import "ExampleNFT2"

transaction {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        let d = ExampleNFT2.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

        if acct.storage.borrow<&ExampleNFT2.Collection>(from: d.storagePath) == nil {
            acct.storage.save(<- ExampleNFT2.createEmptyCollection(nftType: Type<@ExampleNFT2.NFT>()), to: ExampleNFT2.CollectionStoragePath)
        }

        acct.capabilities.unpublish(d.publicPath)
        acct.capabilities.publish(
            acct.capabilities.storage.issue<&{ExampleNFT2.ExampleNFT2CollectionPublic, NonFungibleToken.CollectionPublic}>(d.storagePath),
            at: d.publicPath
        )

        acct.capabilities.storage.issue<auth(NonFungibleToken.Withdraw) &{ExampleNFT2.ExampleNFT2CollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider}>(d.storagePath)
    }
}
