import "NonFungibleToken"
import "MetadataViews"

import "ExampleNFT"

transaction {
    prepare(acct: auth(BorrowValue, SaveValue) &Account) {
        if acct.storage.borrow<&ExampleNFT.Collection>(from: ExampleNFT.CollectionStoragePath) == nil {
            acct.storage.save(<- ExampleNFT.createEmptyCollection(), to: ExampleNFT.CollectionStoragePath)
        }
    }
}
