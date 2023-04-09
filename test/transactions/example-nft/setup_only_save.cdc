import "NonFungibleToken"
import "MetadataViews"

import "ExampleNFT"

transaction {
    prepare(acct: AuthAccount) {
        if acct.borrow<&ExampleNFT.Collection>(from: ExampleNFT.CollectionStoragePath) == nil {
            acct.save(<- ExampleNFT.createEmptyCollection(), to: ExampleNFT.CollectionStoragePath)
        }
    }
}
