import "FungibleToken"
import "ExampleToken"

import "HybridCustody"
import "FungibleTokenMetadataViews"

transaction(amount: UFix64, to: Address, child: Address) {

    // The Vault resource that holds the tokens that are being transferred
    let paymentVault: @{FungibleToken.Vault}
    let vaultData: FungibleTokenMetadataViews.FTVaultData

    prepare(signer: auth(Storage) &Account) {
        // signer is the parent account
        // get the manager resource and borrow childAccount
        let m = signer.storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager does not exist")
        let childAcct = m.borrowAccount(addr: child) ?? panic("child account not found")
        
        self.vaultData = ExampleToken.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
            ?? panic("Could not get the vault data view for ExampleToken")

        //get Ft cap from child account
        let capType = Type<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>()
        let controllerID = childAcct.getControllerIDForType(type: capType, forPath: self.vaultData.storagePath)
            ?? panic("no controller found for capType")
        
        let cap = childAcct.getCapability(controllerID: controllerID, type: capType) ?? panic("no cap found")
        let providerCap = cap as! Capability<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>
        assert(providerCap.check(), message: "invalid provider capability")
        
        // Get a reference to the child's stored vault
        let vaultRef = providerCap.borrow()!

        // Withdraw tokens from the signer's stored vault
        self.paymentVault <- vaultRef.withdraw(amount: amount)
    }

    execute {

        // Get the recipient's public account object
        let recipient = getAccount(to)

        // Get a reference to the recipient's Receiver
        let receiverRef = recipient.capabilities.get<&{FungibleToken.Receiver}>(self.vaultData.receiverPath)!.borrow()
			?? panic("Could not borrow receiver reference to the recipient's Vault")

        // Deposit the withdrawn tokens in the recipient's receiver
        receiverRef.deposit(from: <-self.paymentVault)
    }
}
 