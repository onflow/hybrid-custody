import "NonFungibleToken"
import "MetadataViews"
import "HybridCustody"

/// Custom struct to make interpretation of NFT & Collection data easy client side
///
pub struct NFTData {
    pub let name: String
    pub let description: String
    pub let thumbnail: String
    pub let resourceID: UInt64
    pub let ownerAddress: Address?
    pub let collectionName: String?
    pub let collectionDescription: String?
    pub let collectionURL: String?
    pub let collectionStoragePathIdentifier: String
    pub let collectionPublicPathIdentifier: String?

    init(
        name: String,
        description: String,
        thumbnail: String,
        resourceID: UInt64,
        ownerAddress: Address?,
        collectionName: String?,
        collectionDescription: String?,
        collectionURL: String?,
        collectionStoragePathIdentifier: String,
        collectionPublicPathIdentifier: String?
    ) {
        self.name = name
        self.description = description
        self.thumbnail = thumbnail
        self.resourceID = resourceID
        self.ownerAddress = ownerAddress
        self.collectionName = collectionName
        self.collectionDescription = collectionDescription
        self.collectionURL = collectionURL
        self.collectionStoragePathIdentifier = collectionStoragePathIdentifier
        self.collectionPublicPathIdentifier = collectionPublicPathIdentifier
    }
}

/// Helper function that retrieves data about all publicly accessible NFTs in an account
///
pub fun getAllViewsFromAddress(_ address: Address): [NFTData] {

    let account: AuthAccount = getAuthAccount(address)
    let data: [NFTData] = []

    let collectionType: Type = Type<@{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>()
    let displayType: Type = Type<MetadataViews.Display>()
    let collectionDisplayType: Type = Type<MetadataViews.NFTCollectionDisplay>()
    let collectionDataType: Type = Type<MetadataViews.NFTCollectionData>()

    // Iterate over each public path
    account.forEachStored(fun (path: StoragePath, type: Type): Bool {
        // Return if not the type we're looking for
        if !type.isInstance(collectionType) && !type.isSubtype(of: collectionType) {
            return true
        }
        if let collectionRef = account
            .borrow<&{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(from: path) {
                
            // Iterate over the Collection's NFTs, continuing if the NFT resolves the views we want
            for id in collectionRef.getIDs() {
                let resolverRef: &{MetadataViews.Resolver} = collectionRef.borrowViewResolver(id: id)
                if let display = resolverRef.resolveView(displayType) as! MetadataViews.Display? {

                    let collectionDisplay = resolverRef.resolveView(collectionDisplayType) as! MetadataViews.NFTCollectionDisplay?
                    let collectionData = resolverRef.resolveView(collectionDataType) as! MetadataViews.NFTCollectionData?

                    data.append(
                        NFTData(
                            name: display.name,
                            description: display.description,
                            thumbnail: display.thumbnail.uri(),
                            resourceID: resolverRef.uuid,
                            ownerAddress: resolverRef.owner?.address,
                            collectionName: collectionDisplay?.name,
                            collectionDescription: collectionDisplay?.description,
                            collectionURL: collectionDisplay?.externalURL?.url,
                            collectionStoragePathIdentifier: path.toString(),
                            collectionPublicPathIdentifier: collectionData?.publicPath?.toString()
                        )
                    )
                }
            }
        }
        return true
    })
    return data
}

/// Script that retrieve data about all publicly accessible NFTs in an account and any of its
/// child accounts
///
pub fun main(address: Address): {Address: [NFTData]} {
    
    let allNFTData: {Address: [NFTData]} = {address: getAllViewsFromAddress(address)}
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
    return allNFTData 
}