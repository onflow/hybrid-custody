import "HybridCustody"
import "NonFungibleToken"

import "ExampleNFT"
import "MetadataViews"

pub fun main(addr: Address): Bool {
    let m = getAccount(addr).getCapability<&HybridCustody.ChildAccount{HybridCustody.AccountPublic}>(HybridCustody.PublicPath).borrow()!

    let d = ExampleNFT.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData
    let cap = m.getPublicCapability(path: d.publicPath, type: Type<&{NonFungibleToken.CollectionPublic}>())
        ?? panic("capability not found")
    
    let cp = cap as! Capability<&{NonFungibleToken.CollectionPublic}>
    assert(cp.check(), message: "collection public capability is not valid")

    return true
}