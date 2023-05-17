import "NonFungibleToken"
import "MetadataViews"
import "HybridCustody"

/// Returns resolved view from given address at specified path or nil if ResolverCollection is not found
///
pub fun getViews(_ address: Address, _ resolverCollectionPath: PublicPath, _ view: Type): {UInt64: AnyStruct} {
    
    let account: PublicAccount = getAccount(address)
    let views: {UInt64: AnyStruct} = {}

    // Borrow the Collection
    if let collection = account
        .getCapability<&{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(resolverCollectionPath).borrow() {
        // Iterate over IDs & resolve the view
        for id in collection.getIDs() {
            views.insert(key: id, collection.borrowViewResolver(id: id)!)
        }
    }

    return views
}

/// Queries for given view across all associated accounts from Collections at the provided PublicPath
///
pub fun main(address: Address, resolverCollectionPath: PublicPath, view: Type): {Address: {UInt64: AnyStruct}} {

    let allViews: {Address: {UInt64: AnyStruct}} = {address: getViews(address, resolverCollectionPath, view)}
    let seen: [Address] = [address]
    
    /* Iterate over any associated accounts */ 
    //
    if let managerRef = getAuthAccount(address).borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) {
        
        for childAccount in managerRef.getChildAddresses() {
            allViews.insert(key: childAccount, getViews(address, resolverCollectionPath, view))
            seen.append(childAccount)
        }

        for ownedAccount in managerRef.getOwnedAddresses() {
            if seen.contains(ownedAccount) == false {
                allViews.insert(key: ownedAccount, getViews(address, resolverCollectionPath, view))
                seen.append(ownedAccount)
            }
        }
    }

    return allViews 
}
