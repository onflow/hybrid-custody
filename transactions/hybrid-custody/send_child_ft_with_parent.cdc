import "FungibleToken"

import "HybridCustody"
import "FungibleTokenMetadataViews"

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

transaction(vaultIdentifier: String, amount: UFix64, to: Address, child: Address) {

    // The Vault resource that holds the tokens that are being transferred
    let paymentVault: @{FungibleToken.Vault}
    let vaultData: FungibleTokenMetadataViews.FTVaultData
    let vaultType: Type

    prepare(signer: auth(Storage) &Account) {
        // signer is the parent account
        // get the manager resource and borrow childAccount
        let m = signer.storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager does not exist")
        let childAcct = m.borrowAccount(addr: child) ?? panic("child account not found")

        // derive the type and defining contract address & name
        self.vaultType = CompositeType(vaultIdentifier) ?? panic("Malformed identifer: ".concat(vaultIdentifier))
        let contractAddress = getContractAddress(from: vaultIdentifier)
            ?? panic("Malformed identifer: ".concat(vaultIdentifier))
        let contractName = getContractName(from: vaultIdentifier)
            ?? panic("Malformed identifer: ".concat(vaultIdentifier))
        // borrow a reference to the defining contract as a FungibleToken contract reference
        let ftContract = getAccount(contractAddress).contracts.borrow<&{FungibleToken}>(name: contractName)
            ?? panic("Provided identifier ".concat(vaultIdentifier).concat(" is not defined as a FungibleToken"))

        // gather the default asset storage data
        self.vaultData = ftContract.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
            ?? panic("Could not get the vault data view for vault ".concat(vaultIdentifier))

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

    pre {
        self.paymentVault.getType() == self.vaultType:
            "Expected vault type ".concat(vaultIdentifier)
            .concat(" but got ").concat(self.paymentVault.getType().identifier)
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
