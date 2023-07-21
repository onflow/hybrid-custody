import "NonFungibleToken"
import "MetadataViews"

import "HybridCustody"

pub fun main(parent: Address): {Address: {Type: [UInt64]}} {
    let manager = getAuthAccount(parent).borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) ?? panic ("manager does not exist")

    var typeIdsWithProvider: {Address: [Type]} = {}

    // Address -> Collection Type -> ownedNFTs
    var accessibleNFTs: {Address: {Type: [UInt64]}}  = {}


    let providerType = Type<Capability<&{NonFungibleToken.Provider}>>()
    let collectionType: Type = Type<@{NonFungibleToken.CollectionPublic}>()

    // Iterate through child accounts
    for address in manager.getChildAddresses() {
        let acct = getAuthAccount(address)
        let foundTypes: [Type] = []
        let nfts: {Type: [UInt64]} = {}
        let childAcct = manager.borrowAccount(addr: address) ?? panic("child account not found")
        // get all private paths
        acct.forEachPrivate(fun (path: PrivatePath, type: Type): Bool {
            // Check which private paths have NFT Provider AND can be borrowed
            if !type.isSubtype(of: providerType){
                return true
            }
            if let cap = childAcct.getCapability(path: path, type: Type<&{NonFungibleToken.Provider}>()) {
                let providerCap = cap as! Capability<&{NonFungibleToken.Provider}> 

                if !providerCap.check(){
                    // if this isn't a provider capability, exit the account iteration function for this path
                    return true
                }
                foundTypes.append(cap.borrow<&AnyResource>()!.getType())
            }
            return true
        })
        typeIdsWithProvider[address] = foundTypes

        // iterate storage, check if typeIdsWithProvider contains the typeId, if so, add to nfts
        acct.forEachStored(fun (path: StoragePath, type: Type): Bool {

            if typeIdsWithProvider[address] == nil {
                return true
            }

            for key in typeIdsWithProvider.keys {
                for idx, value in typeIdsWithProvider[key]! {
                    let value = typeIdsWithProvider[key]!

                    if value[idx] != type {
                        continue
                    } else {
                        if type.isInstance(collectionType) {
                            continue
                        }
                        if let collection = acct.borrow<&{NonFungibleToken.CollectionPublic}>(from: path) { 
                            nfts.insert(key: type, collection.getIDs())
                        }
                        continue
                    }
                }
            }
            return true
        })
        accessibleNFTs[address] = nfts
    }
    return accessibleNFTs
}