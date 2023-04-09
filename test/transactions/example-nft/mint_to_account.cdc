import "NonFungibleToken"
import "MetadataViews"

import "ExampleNFT"

transaction(receiver: Address, name: String, description: String, thumbnail: String) {
    let minter: &ExampleNFT.NFTMinter

    prepare(acct: AuthAccount) {
        self.minter = acct.borrow<&ExampleNFT.NFTMinter>(from: ExampleNFT.MinterStoragePath) ?? panic("minter not found")
    }

    execute {
        let d = ExampleNFT.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

        let c = getAccount(receiver).getCapability<&{NonFungibleToken.CollectionPublic}>(d.publicPath)
        let r = c.borrow() ?? panic("no receiver collection")
        self.minter.mintNFT(recipient: r, name: name, description: description, thumbnail: thumbnail, royalties: [])
    }
}
