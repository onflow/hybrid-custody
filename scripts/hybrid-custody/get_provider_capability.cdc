import "HybridCustody"
import "NonFungibleToken"

import "ExampleNFT"
import "MetadataViews"

pub fun main(addr: Address): Bool {
    let m = getAuthAccount(addr).getCapability<&HybridCustody.ChildAccount{HybridCustody.AccountPrivate}>(HybridCustody.PrivatePath).borrow()!

    let d = ExampleNFT.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData
    let cap = m.getCapability(path: d.providerPath, type: Type<&{NonFungibleToken.Provider}>())
        ?? panic("capability not found")
    
    let cp = cap as! Capability<&{NonFungibleToken.Provider}>
    assert(cp.check(), message: "collection public capability is not valid")

    return true
}