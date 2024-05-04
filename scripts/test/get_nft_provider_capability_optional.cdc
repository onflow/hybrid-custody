import "HybridCustody"

import "NonFungibleToken"
import "MetadataViews"
import "ExampleNFT"

// Verify that a child address borrowed as a child will let the parent borrow an NFT provider capability
access(all) fun main(parent: Address, child: Address, returnsNil: Bool): Bool {
    let acct = getAuthAccount<auth(Storage) &Account>(parent)
    let manager = acct.storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
        ?? panic("manager does not exist")

    let childAcct = manager.borrowAccount(addr: child) ?? panic("child account not found")

    let collectionData = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

    let type = Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider}>()
    let controllerID = childAcct.getControllerIDForType(type: type, forPath: collectionData.storagePath)
        ?? panic("could not find controller for desired type")

    let nakedCap = childAcct.getCapability(controllerID: controllerID, type: type)

    return returnsNil ? nakedCap == nil : nakedCap?.borrow<&{NonFungibleToken.Provider}>() != nil
}