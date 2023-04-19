import "ExampleNFT"
import "AddressUtils"
import "StringUtils"
import "MetadataViews"
import "NonFungibleToken"

import "NFTProviderFactory"

pub fun main(addr: Address) {
    let acct = getAuthAccount(addr)
    let ref = &acct as &AuthAccount

    let factory = NFTProviderFactory.Factory()

    let d = ExampleNFT.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

    let provider = factory.getCapability(acct: ref, path: d.providerPath) as! Capability<&{NonFungibleToken.Provider}>
}