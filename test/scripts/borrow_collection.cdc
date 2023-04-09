import "RestrictedChildAccount"

import "NonFungibleToken"
import "MetadataViews"

import "ExampleNFT"
   
pub fun main(parent: Address, childName: String): Bool {
    let d = ExampleNFT.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

    let acct = getAuthAccount(parent)
    let m = acct.borrow<&RestrictedChildAccount.Manager>(from: RestrictedChildAccount.StoragePath)
        ?? panic("Manager not found")

    let child = m.borrowByNamePublic(name: childName) ?? panic("account not found with given name: ".concat(childName))

    let collection = child.getCollectionPublicCap(path: d.publicPath).borrow()
        ?? panic("could not borrow public collection")

    return true
}