import "HybridCustody"

import "NonFungibleToken"
import "MetadataViews"
import "ExampleNFT"

// Verify that a child address borrowed as a child will let the parent borrow an NFT provider capability
access(all) fun main(parent: Address, child: Address) {
    let acct = getAuthAccount<auth(Storage) &Account>(parent)
    let m = acct.storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
        ?? panic("manager does not exist")

    let childAcct = m.borrowAccount(addr: child) ?? panic("child account not found")

    let d = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData
    let type = Type<&{NonFungibleToken.CollectionPublic}>()
    let controllerId = childAcct.getControllerIDForType(type: type, forPath: d.storagePath)
        ?? panic("no controller ID found for desired type")

    let nakedCap = childAcct.getCapability(controllerID: controllerId, type: type)
        ?? panic("capability not found")

    let cap = nakedCap as! Capability<&{NonFungibleToken.CollectionPublic}>
    cap.borrow() ?? panic("unable to borrow nft provider collection")
}