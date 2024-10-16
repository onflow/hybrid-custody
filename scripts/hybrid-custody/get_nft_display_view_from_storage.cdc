import "NonFungibleToken"
import "ViewResolver"
import "MetadataViews"
import "HybridCustody"

/// Returns resolved Display from given address at specified path for each ID or nil if ResolverCollection is not found
///
access(all) fun getViews(_ address: Address, _ collectionPath: StoragePath): {UInt64: MetadataViews.Display} {

    let account = getAuthAccount<auth(BorrowValue) &Account>(address)
    let views: {UInt64: MetadataViews.Display} = {}

    // Borrow the Collection
    if let collection = account.storage
        .borrow<&{NonFungibleToken.Collection}>(from: collectionPath) {
        // Iterate over IDs & resolve the view
        for id in collection.getIDs() {
            if let resolver = collection.borrowViewResolver(id: id) {
                if let display = resolver.resolveView(Type<MetadataViews.Display>()) as! MetadataViews.Display? {
                    views.insert(key: id, display)
                }
            }
        }
    }

    return views
}

/// Queries for the MetadataViews.Display of each NFT across all associated accounts from Collections at the provided
/// PublicPath
///
access(all) fun main(address: Address, collectionPath: StoragePath): {Address: {UInt64: MetadataViews.Display}} {

    let allViews: {Address: {UInt64: MetadataViews.Display}} = {address: getViews(address, collectionPath)}
    let seen: [Address] = [address]

    /* Iterate over any associated accounts */
    //
    if let managerRef = getAuthAccount<auth(BorrowValue) &Account>(address).storage
        .borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) {

        for childAccount in managerRef.getChildAddresses() {
            allViews.insert(key: childAccount, getViews(address, collectionPath))
            seen.append(childAccount)
        }

        for ownedAccount in managerRef.getOwnedAddresses() {
            if seen.contains(ownedAccount) == false {
                allViews.insert(key: ownedAccount, getViews(address, collectionPath))
                seen.append(ownedAccount)
            }
        }
    }

    return allViews
}
