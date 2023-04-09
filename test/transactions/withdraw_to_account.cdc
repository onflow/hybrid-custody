import ReadOnlyChildAccount from "ReadOnlyChildAccount"

import NonFungibleToken from "NonFungibleToken"
import MetadataViews from "MetadataViews"

import ExampleNFT from "ExampleNFT"

transaction(childName: String, id: UInt64) {
    let provider: &{NonFungibleToken.Provider}
    let receiver: &{NonFungibleToken.CollectionPublic}

    prepare(acct: AuthAccount) {
        let d = ExampleNFT.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

        let manager = acct.borrow<&ReadOnlyChildAccount.Manager>(from: ReadOnlyChildAccount.StoragePath) ?? panic("manager not found")
        let account = manager.borrowByName(name: childName) ?? panic("child account not found")
        self.provider = account.getCollectionProviderCap(path: d.providerPath).borrow() ?? panic("provider not found")

        self.receiver = acct.borrow<&{NonFungibleToken.CollectionPublic}>(from: d.storagePath) ?? panic("collection not found")
    }

    execute {
        let nft <- self.provider.withdraw(withdrawID: id)
        self.receiver.deposit(token: <-nft)
    }
}
