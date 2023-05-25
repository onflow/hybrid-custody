import "NonFungibleToken"
import "MetadataViews"

import "ExampleNFT2"

transaction {
    prepare(acct: AuthAccount) {
        let d = ExampleNFT2.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

        if acct.borrow<&ExampleNFT2.Collection>(from: d.storagePath) == nil {
            acct.save(<- ExampleNFT2.createEmptyCollection(), to: ExampleNFT2.CollectionStoragePath)
        }

        acct.unlink(d.publicPath)
        acct.link<&ExampleNFT2.Collection{ExampleNFT2.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic}>(d.publicPath, target: d.storagePath)

        acct.unlink(d.providerPath)
        acct.link<&ExampleNFT2.Collection{ExampleNFT2.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider}>(d.providerPath, target: d.storagePath)
    }
}
