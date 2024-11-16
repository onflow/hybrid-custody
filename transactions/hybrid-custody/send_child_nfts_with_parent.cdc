import "NonFungibleToken"
import "MetadataViews"
import "ExampleNFT"

import "HybridCustody"
import "FungibleTokenMetadataViews"

transaction(ids: [UInt64], to: Address, child: Address) {

    // reference to the child account's Collection Provider that holds the NFT being transferred
    let provider: auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider}
    let collectionData: MetadataViews.NFTCollectionData

    // signer is the parent account
    prepare(signer: auth(Storage) &Account) {
        // get the manager resource and borrow childAccount
        let m = signer.storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager does not exist")
        let childAcct = m.borrowAccount(addr: child) ?? panic("child account not found")
        
        self.collectionData = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>()) as! MetadataViews.NFTCollectionData?
            ?? panic("Could not get the vault data view for ExampleNFT")

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
 