import "HybridCustody"

import "NonFungibleToken"
import "MetadataViews"
import "ExampleNFT"

// Verify that a child address borrowed as a child will let the parent borrow an NFT provider capability
pub fun main(parent: Address, child: Address, returnsNil: Bool): Bool {
    let acct = getAuthAccount(parent)
    let manager = acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
        ?? panic("manager does not exist")

    let childAcct = manager.borrowAccount(addr: child) ?? panic("child account not found")

    let collectionData = ExampleNFT.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

    let nakedCap = childAcct.getCapability(path: collectionData.providerPath, type: Type<&{NonFungibleToken.Provider}>())

    return returnsNil ? nakedCap == nil : nakedCap?.borrow<&{NonFungibleToken.Provider}>() != nil
}