import "CapabilityDelegator"

import "NonFungibleToken"
import "MetadataViews"
import "ExampleNFT"

transaction {
    prepare(acct: auth(BorrowValue, Capabilities) &Account) {
        let delegator = acct.storage.borrow<auth(Mutate) &CapabilityDelegator.Delegator>(from: CapabilityDelegator.StoragePath)
            ?? panic("delegator not found")
        
        let d = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData
        
        let sharedCap = acct.capabilities.storage.issue<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider}>(d.storagePath)
        
        delegator.removeCapability(cap: sharedCap)

        acct.capabilities.storage.getController(byCapabilityID: sharedCap.id)!.delete()
    }
}