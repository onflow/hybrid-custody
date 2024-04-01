import "NonFungibleToken"
import "MetadataViews"

import "ExampleNFT"

transaction(receiver: Address, name: String, description: String, thumbnail: String) {
    let minter: &ExampleNFT.NFTMinter

    prepare(acct: auth(BorrowValue) &Account) {
        self.minter = acct.storage.borrow<&ExampleNFT.NFTMinter>(from: ExampleNFT.MinterStoragePath) ?? panic("minter not found")
    }

    execute {
        let d = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

        let c = getAccount(receiver).capabilities.get<&{NonFungibleToken.CollectionPublic}>(d.publicPath)
            ?? panic("no receiver capability found")
        let r = c.borrow() ?? panic("could not borrow collection")
        self.minter.mintNFT(recipient: r, name: name, description: description, thumbnail: thumbnail, royaltyReceipient: self.minter.owner!.address)
    }
}
