import "HybridCustody"

import "NonFungibleToken"
import "MetadataViews"
import "ExampleNFT"

// Verify that a child address borrowed as a child will let the parent borrow an NFT provider capability
pub fun main(parent: Address, child: Address) {
    let acct = getAuthAccount(parent)
    let m = acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
        ?? panic("manager does not exist")

    let childAcct = m.borrowAccount(addr: child) ?? panic("child account not found")

    let d = ExampleNFT.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

    let nakedCap = childAcct.getCapability(path: d.providerPath, type: Type<&{NonFungibleToken.CollectionPublic}>())
        ?? panic("capability not found")

    let cap = nakedCap as! Capability<&{NonFungibleToken.CollectionPublic}>
    cap.borrow() ?? panic("unable to borrow nft provider collection")
}