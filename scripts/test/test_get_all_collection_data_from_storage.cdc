import "NonFungibleToken"
import "MetadataViews"
import "HybridCustody"

/* 
 * TEST SCRIPT
 * This script is a replication of that found in hybrid-custody/get_all_collection_data_from_storage as it's the best as
 * as can be done without accessing the script's return type in the Cadence testing framework
 */

/// Assertion method to ensure passing test
///
pub fun assertPassing(result: {Address: [MetadataViews.NFTCollectionData]}, expectedAddressToCollectionLength: {Address: Int}) {
    for address in result.keys {
        if expectedAddressToCollectionLength[address] == nil {
            panic("Address ".concat(address.toString()).concat(" found but not expected!"))
        }
        if result[address]!.length != expectedAddressToCollectionLength[address]! {
            panic("Incorrect number of NFTCollectionData views found for ".concat(address.toString()))
        }
    }
}

/// Helper function that retrieves data about all publicly accessible NFTs in an account
///
pub fun getAllViewsFromAddress(_ address: Address): [MetadataViews.NFTCollectionData] {

    let account: AuthAccount = getAuthAccount(address)
    let data: [MetadataViews.NFTCollectionData] = []

    let collectionType: Type = Type<@{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>()
    let viewType: Type = Type<MetadataViews.NFTCollectionData>()

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
            // Otherwise, attempt to get the NFTCollectionData & append if exists
            if let dataView = collectionRef.borrowViewResolver(id: ids[0]).resolveView(viewType) as! MetadataViews.NFTCollectionData? {
                data.append(dataView)
            }
        }
        return true
    })
    return data
}

/// Script that retrieve data about all NFT Collections in the storage of an account and any of its child accounts
///
// pub fun main(address: Address): {Address: [MetadataViews.NFTCollectionData]} {
pub fun main(address: Address, expectedAddressToCollectionLength: {Address: Int}) {
    
    let allNFTData: {Address: [MetadataViews.NFTCollectionData]} = {address: getAllViewsFromAddress(address)}
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
 