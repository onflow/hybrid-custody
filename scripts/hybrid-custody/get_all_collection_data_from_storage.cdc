import "NonFungibleToken"
import "MetadataViews"
import "HybridCustody"

/// Helper function that retrieves data about all publicly accessible NFTs in an account
///
access(all) fun getAllViewsFromAddress(_ address: Address): [MetadataViews.NFTCollectionData] {

    let account = getAuthAccount<auth(BorrowValue) &Account>(address)
    let data: [MetadataViews.NFTCollectionData] = []

    let collectionType: Type = Type<@{NonFungibleToken.Collection}>()
    let viewType: Type = Type<MetadataViews.NFTCollectionData>()

    // Iterate over each public path
    account.storage.forEachStored(fun (path: StoragePath, type: Type): Bool {
        // Return early if the collection is broken or is not the type we're looking for
        if type.isRecovered || (!type.isInstance(collectionType) && !type.isSubtype(of: collectionType)) {
            return true
        }
        if let collectionRef = account.storage.borrow<&{NonFungibleToken.Collection}>(from: path) {
            // Return early if no Resolver found in the Collection
            let ids: [UInt64]= collectionRef.getIDs()
            if ids.length == 0 {
                return true
            }
            // Otherwise, attempt to get the NFTCollectionData & append if exists
            if let resolver = collectionRef.borrowViewResolver(id: ids[0]) {
                if let dataView = resolver.resolveView(viewType) as! MetadataViews.NFTCollectionData? {
                    data.append(dataView)
                }
            }
        }
        return true
    })
    return data
}

/// Script that retrieve data about all NFT Collections in the storage of an account and any of its child accounts
///
access(all) fun main(address: Address): {Address: [MetadataViews.NFTCollectionData]} {
    
    let allNFTData: {Address: [MetadataViews.NFTCollectionData]} = {address: getAllViewsFromAddress(address)}
    let seen: [Address] = [address]
    
    /* Iterate over any child accounts */ 
    //
    if let managerRef = getAccount(address).capabilities.borrow<&HybridCustody.Manager>(HybridCustody.ManagerPublicPath) {

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
    return allNFTData 
}