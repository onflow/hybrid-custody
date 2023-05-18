// Original script imports
import "NonFungibleToken"
import "MetadataViews"
import "HybridCustody"

// Testing purposes only
import "ExampleNFT"

/* 
 * TEST SCRIPT
 * This script is a replication of that found in hybrid-custody/get_all_collection_views_from_storage as it's the best as
 * as can be done without accessing the script's return type in the Cadence testing framework
 */

/// Assertion method to ensure passing test
///
pub fun assertPassing(result: {Address: [MetadataViews.NFTCollectionDisplay]}, expectedAddressToCollectionLength: {Address: Int}) {
    // Taken from ExampleNFT.resolveView() which was not returning a view for some reason
    let expectedView = MetadataViews.Media(
        file: MetadataViews.HTTPFile(
            url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
        ),
        mediaType: "image/svg+xml"
    )
    for address in result.keys {
        if expectedAddressToCollectionLength[address] == nil {
            panic("Address ".concat(address.toString()).concat(" found but not expected!"))
        }
        if result[address]!.length != expectedAddressToCollectionLength[address]! {
            panic("Incorrect number of NFTCollectionDisplay views found for ".concat(address.toString()))
        }
    }
}

/// Helper function that retrieves data about all publicly accessible NFTs in an account
///
pub fun getAllViewsFromAddress(_ address: Address): [MetadataViews.NFTCollectionDisplay] {

    let account: AuthAccount = getAuthAccount(address)
    let data: [MetadataViews.NFTCollectionDisplay] = []

    let collectionType: Type = Type<@{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>()
    let collectionDisplayType: Type = Type<MetadataViews.NFTCollectionDisplay>()

    // Iterate over each public path
    account.forEachStored(fun (path: StoragePath, type: Type): Bool {
        // Return if not the type we're looking for
        if !type.isInstance(collectionType) && !type.isSubtype(of: collectionType) {
            return true
        }
        if let collectionRef = account
            .borrow<&{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(from: path) {
            // Return early if no Resolver found in the Collection
            let ids: [UInt64]= collectionRef.getIDs()
            if ids.length == 0 {
                return true
            }
            // Otherwise, attempt to get the NFTCollectionDisplay & append if exists
            if let display = collectionRef.borrowViewResolver(id: ids[0]).resolveView(collectionDisplayType) as! MetadataViews.NFTCollectionDisplay? {
                data.append(display)
            }
        }
        return true
    })
    return data
}

/// Script that retrieve data about all NFT Collections in the storage of an account and any of its child accounts
///
// pub fun main(address: Address): {Address: [MetadataViews.NFTCollectionDisplay]} {
pub fun main(address: Address, expectedAddressToCollectionLength: {Address: Int}) {
    
    let allNFTData: {Address: [MetadataViews.NFTCollectionDisplay]} = {address: getAllViewsFromAddress(address)}
    let seen: [Address] = [address]
    
    /* Iterate over any child accounts */ 
    //
    if let managerRef = getAccount(address).getCapability<&HybridCustody.Manager{HybridCustody.ManagerPublic}>(
            HybridCustody.ManagerPublicPath
        ).borrow() {

        for childAddress in managerRef.getChildAddresses() {
            allNFTData.insert(key: childAddress, getAllViewsFromAddress(childAddress))
        }

        for ownedAddress in managerRef.getOwnedAddresses() {
            if seen.contains(ownedAddress) == false {
                allNFTData.insert(key: ownedAddress, getAllViewsFromAddress(ownedAddress))
                seen.append(ownedAddress)
            }
        }
    }
    // Assert instead of return here
    assertPassing(result: allNFTData, expectedAddressToCollectionLength: expectedAddressToCollectionLength)
    // return allNFTData 
}