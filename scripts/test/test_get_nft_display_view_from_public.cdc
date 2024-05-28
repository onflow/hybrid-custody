import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"
import "ExampleNFT"

import "HybridCustody"

/* 
 * TEST SCRIPT
 * This script is a replication of that found in hybrid-custody/get_nft_display_view_from_public as it's the best as
 * as can be done without accessing the script's return type in the Cadence testing framework
 */

/// Assertion method to ensure passing test
///
access(all) fun assertPassing(result: {Address: {UInt64: MetadataViews.Display}}, expectedAddressToIDs: {Address: [UInt64]}) {
    for address in result.keys {
        let expectedIDs: [UInt64] = expectedAddressToIDs[address] ?? panic("address expected but not found")

        for id in result[address]!.keys {
            assert(expectedIDs.contains(id), message: "id expected but was not found")
        }
    }
}

/// Returns resolved Display from given address at specified path for each ID or nil if ResolverCollection is not found
///
access(all) fun getViews(_ address: Address, _ resolverCollectionPath: PublicPath): {UInt64: MetadataViews.Display} {
    let account: &Account = getAccount(address)
    let views: {UInt64: MetadataViews.Display} = {}

    // Borrow the Collection
    if let collection = account
        .capabilities.get<&{NonFungibleToken.CollectionPublic}>(resolverCollectionPath)!.borrow() {
        // Iterate over IDs & resolve the view
        for id in collection.getIDs() {
            let nft = collection.borrowNFT(id) ?? panic("could not borrow NFT")
            let display = nft.resolveView(Type<MetadataViews.Display>())! as! MetadataViews.Display
            views.insert(key: id, display)
        }
    }

    return views
}

/// Queries for MetadataViews.Display each NFT across all associated accounts from Collections at the provided
/// PublicPath
///
access(all) fun main(address: Address, resolverCollectionPath: PublicPath, expectedAddressToIDs: {Address: [UInt64]}) {
    let allViews: {Address: {UInt64: MetadataViews.Display}} = {address: getViews(address, resolverCollectionPath)}
    let seen: [Address] = [address]
    
    /* Iterate over any associated accounts */ 
    //
    if let managerRef = getAuthAccount<auth(Storage) &Account>(address).storage.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) {
        
        for childAccount in managerRef.getChildAddresses() {
            let views = getViews(childAccount, resolverCollectionPath)
            allViews.insert(key: childAccount, views)
            seen.append(childAccount)
        }

        for ownedAccount in managerRef.getOwnedAddresses() {
            if seen.contains(ownedAccount) == false {
                allViews.insert(key: ownedAccount, getViews(address, resolverCollectionPath))
                seen.append(ownedAccount)
            }
        }
    }
    // Assert instead of return for testing purposes here
    assertPassing(result: allViews, expectedAddressToIDs: expectedAddressToIDs)
    // return allViews 
}
 