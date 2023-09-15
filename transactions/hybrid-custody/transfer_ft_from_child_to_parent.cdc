import "FungibleToken"

import "HybridCustody"

/* --- Helper Methods --- */
//
/// Returns a type identifier for an FungibleToken Vault
///
access(all) fun deriveVaultTypeIdentifier(_ contractAddress: Address, _ contractName: String): String {
    return "A.".concat(withoutPrefix(contractAddress.toString())).concat(".").concat(contractName).concat(".Vault")
}

/// Taken from AddressUtils private method
///
access(all) fun withoutPrefix(_ input: String): String{
    var address=input

    //get rid of 0x
    if address.length>1 && address.utf8[1] == 120 {
        address = address.slice(from: 2, upTo: address.length)
    }

    //ensure even length
    if address.length%2==1{
        address="0".concat(address)
    }
    return address
}

/* --- Transaction Body --- */

/// Transaction for generalized FungibleToken transfers between child & parent account.
/// Withdraws tokens from a child account and deposits them into the signing parent's account, setting up the FT Vault
/// if needed.
///
transaction(
    ftContractAddress: Address,
    ftContractName: String,
    amount: UFix64,
    fromChild: Address,
    storagePath: StoragePath,
    providerPath: PrivatePath,
    receiverPath: PublicPath
) {

    let provider: &{FungibleToken.Provider}
    let receiver: &{FungibleToken.Receiver}

    prepare(signer: AuthAccount) {
        /* --- Gather FT Provider from ChildAccount --- */
        //
        // Borrow the Manager from the signing parent's account
        let m = signer.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager does not exist")
        let childAcct = m.borrowAccount(addr: fromChild) ?? panic("child account not found")
        
        // Get FT.Provider Capability from child account
        let cap = childAcct.getCapability(path: /private/exampleTokenProvider, type: Type<&{FungibleToken.Provider}>()) ?? panic("no cap found")
        let providerCap = cap as! Capability<&{FungibleToken.Provider}>
        
        // Check that the capability is valid & borrow a reference to the Provider
        assert(providerCap.check(), message: "invalid provider capability")
        self.provider = providerCap.borrow()!

        /* --- Parent account setup --- */
        //
        // Setup parent Vault if needed
        let vaultIdentifier = deriveVaultTypeIdentifier(ftContractAddress, ftContractName)
        if signer.type(at: storagePath)?.identifier == vaultIdentifier {
            let ftContract = getAccount(ftContractAddress).contracts.borrow<&FungibleToken>(name: ftContractName)
                ?? panic("Could not borrow reference to the FungibleToken contract")
            let vault <- ftContract.createEmptyVault()
            signer.save(<-vault, to: storagePath)
        }
        // Link Capabilities if needed
        if !signer.getCapability<&{FungibleToken.Provider}>(providerPath).check() {
            signer.unlink(providerPath)
            signer.link<&{FungibleToken.Provider}>(providerPath, target: storagePath)
        }
        if !signer.getCapability<&{FungibleToken.Balance, FungibleToken.Receiver}>(receiverPath).check() {
            signer.unlink(receiverPath)
            signer.link<&{FungibleToken.Balance, FungibleToken.Receiver}>(receiverPath, target: storagePath)
        }

        // Get a reference to the signer's Receiver
        self.receiver = signer.getCapability(receiverPath)
            .borrow<&{FungibleToken.Receiver}>()
			?? panic("Could not borrow receiver reference to the recipient's Vault")
    }

    execute {
        // Complete transfer
        let paymentVault <- self.provider.withdraw(amount: amount)
        self.receiver.deposit(from: <- paymentVault)
    }
}
 