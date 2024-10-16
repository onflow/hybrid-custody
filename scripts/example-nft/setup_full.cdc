import "NonFungibleToken"
import "MetadataViews"

import "ExampleNFT"

transaction {
    prepare(acct: auth(BorrowValue, SaveValue, PublishCapability, UnpublishCapability) &Account) {
        let d = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

        if acct.storage.borrow<&ExampleNFT.Collection>(from: d.storagePath) == nil {
            acct.storage.save(<- ExampleNFT.createEmptyCollection(), to: d.storagePath)
        }

        acct.capabilities.unpublish(d.publicPath)
        let cap = acct.capabilities.storage.issue<&ExampleNFT.Collection>(d.storagePath)
        acct.capabilities.publish(cap, at: d.publicPath)
    }
}
