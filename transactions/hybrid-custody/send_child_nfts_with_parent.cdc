import "NonFungibleToken"
import "MetadataViews"

import "HybridCustody"

/// Returns the contract address from a type identifier. Type identifiers are in the form of
/// A.<ADDRESS>.<CONTRACT_NAME>.<OBJECT_NAME> where ADDRESS omits the `0x` prefix
///
access(all)
view fun getContractAddress(from identifier: String): Address? {
    let parts = identifier.split(separator: ".")
    return parts.length == 4 ? Address.fromString("0x".concat(parts[1])) : nil
}

/// Returns the contract name from a type identifier. Type identifiers are in the form of
/// A.<ADDRESS>.<CONTRACT_NAME>.<OBJECT_NAME> where ADDRESS omits the `0x` prefix
///
access(all)
view fun getContractName(from identifier: String): String? {
    let parts = identifier.split(separator: ".")
    return parts.length == 4 ? parts[2] : nil
}

transaction(nftIdentifier: String, ids: [UInt64], to: Address, child: Address) {

    // reference to the child account's Collection Provider that holds the NFT being transferred
    let provider: auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider}
    let collectionData: MetadataViews.NFTCollectionData
    let nftType: Type

    // signer is the parent account
    prepare(signer: auth(Storage) &Account) {
        // get the manager resource and borrow childAccount
        let m = signer.storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager does not exist")
        let childAcct = m.borrowAccount(addr: child) ?? panic("child account not found")

        // derive the type and defining contract address & name
        self.nftType = CompositeType(nftIdentifier) ?? panic("Malformed identifer: ".concat(nftIdentifier))
        let contractAddress = getContractAddress(from: nftIdentifier)
            ?? panic("Malformed identifer: ".concat(nftIdentifier))
        let contractName = getContractName(from: nftIdentifier)
            ?? panic("Malformed identifer: ".concat(nftIdentifier))
        // borrow a reference to the defining contract as a FungibleToken contract reference
        let nftContract = getAccount(contractAddress).contracts.borrow<&{NonFungibleToken}>(name: contractName)
            ?? panic("Provided identifier ".concat(nftIdentifier).concat(" is not defined as a NonFungibleToken"))
        
        // gather the default asset storage data
        self.collectionData = nftContract.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>()) as! MetadataViews.NFTCollectionData?
            ?? panic("Could not get the vault data view for NFT ".concat(nftIdentifier))

        // get Provider capability from child account
        let capType = Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider}>()
        let controllerID = childAcct.getControllerIDForType(type: capType, forPath: self.collectionData.storagePath)
            ?? panic("no controller found for capType")
        
        let cap = childAcct.getCapability(controllerID: controllerID, type: capType) ?? panic("no cap found")
        let providerCap = cap as! Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider}>
        assert(providerCap.check(), message: "invalid provider capability")
        
        // get a reference to the child's stored NFT Collection Provider
        self.provider = providerCap.borrow()!
    }

    execute {
        // get the recipient's public account object
        let recipient = getAccount(to)

        // get a reference to the recipient's NFT Receiver
        let receiverRef = recipient.capabilities.borrow<&{NonFungibleToken.Receiver}>(self.collectionData.publicPath)
			?? panic("Could not borrow receiver reference to the recipient's Vault")

        for id in ids {
            // withdraw the NFT from the child account's collection & deposit to the recipient's Receiver
            receiverRef.deposit(
                token: <-self.provider.withdraw(withdrawID: id)
            )
        }
    }
}
 