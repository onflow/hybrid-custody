import "FungibleToken"
import "ExampleToken"

import "HybridCustody"

transaction(amount: UFix64, to: Address, child: Address) {

    // The Vault resource that holds the tokens that are being transferred
    let paymentVault: @FungibleToken.Vault

    prepare(signer: AuthAccount) {
        // signer is the parent account
        // get the manager resource and borrow childAccount
        let m = signer.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager does not exist")
        let childAcct = m.borrowAccount(addr: child) ?? panic("child account not found")
        
        //get Ft cap from child account
        let cap = childAcct.getCapability(path: /private/exampleTokenProvider, type: Type<&{FungibleToken.Provider}>()) ?? panic("no cap found")
        let providerCap = cap as! Capability<&{FungibleToken.Provider}>
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
        let receiverRef = recipient.getCapability(/public/exampleTokenReceiver)
            .borrow<&{FungibleToken.Receiver}>()
			?? panic("Could not borrow receiver reference to the recipient's Vault")

        // Deposit the withdrawn tokens in the recipient's receiver
        receiverRef.deposit(from: <-self.paymentVault)
    }
}
 