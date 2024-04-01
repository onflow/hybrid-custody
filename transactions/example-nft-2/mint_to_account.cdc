import "NonFungibleToken"
import "MetadataViews"

import "ExampleNFT2"

transaction(receiver: Address, name: String, description: String, thumbnail: String) {
    let minter: &ExampleNFT2.NFTMinter

    prepare(acct: auth(BorrowValue) &Account) {
        self.minter = acct.storage.borrow<&ExampleNFT2.NFTMinter>(from: ExampleNFT2.MinterStoragePath) ?? panic("minter not found")
    }

    execute {
        let d = ExampleNFT2.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

        let c = getAccount(receiver).capabilities.get<&{NonFungibleToken.CollectionPublic}>(d.publicPath) ?? panic("receiver capability was nil")
        let r = c.borrow() ?? panic("no receiver collection")
        self.minter.mintNFT(recipient: r, name: name, description: description, thumbnail: thumbnail, royaltyReceipient: self.minter.owner!.address)
    }
}
