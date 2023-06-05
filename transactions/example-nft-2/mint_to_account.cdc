import "NonFungibleToken"
import "MetadataViews"

import "ExampleNFT2"

transaction(receiver: Address, name: String, description: String, thumbnail: String) {
    let minter: &ExampleNFT2.NFTMinter

    prepare(acct: AuthAccount) {
        self.minter = acct.borrow<&ExampleNFT2.NFTMinter>(from: ExampleNFT2.MinterStoragePath) ?? panic("minter not found")
    }

    execute {
        let d = ExampleNFT2.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

        let c = getAccount(receiver).getCapability<&{NonFungibleToken.CollectionPublic}>(d.publicPath)
        let r = c.borrow() ?? panic("no receiver collection")
        self.minter.mintNFT(recipient: r, name: name, description: description, thumbnail: thumbnail, royalties: [])
    }
}
