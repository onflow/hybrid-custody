import "FungibleToken"

/// Struct containing the paths to the vault's storage, provider and receiver
///
pub struct FTVaultPaths {
    pub let vaultIdentifier: String
    pub let storagePath: StoragePath
    pub let providerPath: CapabilityPath?
    pub let receiverPath: CapabilityPath?

    init(
        vaultIdentifier: String,
        storagePath: StoragePath,
        providerPath: CapabilityPath?,
        receiverPath: CapabilityPath?
    ) {
        self.vaultIdentifier = vaultIdentifier
        self.storagePath = storagePath
        self.providerPath = providerPath
        self.receiverPath = receiverPath
    }
}

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

/* --- Main Script --- */
//
/// Returns the paths for a given vault in the specified account address 
///
pub fun main(address: Address, ftAddress: Address, ftName: String): FTVaultPaths? {

    let account = getAuthAccount(address)
    let vaultIdentifier = deriveVaultTypeIdentifier(ftAddress, ftName)
    let receiverType = Type<Capability<&{FungibleToken.Receiver}>>()
    let providerType = Type<Capability<&{FungibleToken.Provider}>>()

    var storagePath: StoragePath? = nil
    var providerPath: CapabilityPath? = nil
    var receiverPath: CapabilityPath? = nil

    // Find the StoragePath for the vault
    account.forEachStored(fun (path: StoragePath, type: Type): Bool {
        if type.identifier == vaultIdentifier {
            storagePath = path
            return false
        }
        return true
    })

    // Return nil early if the Vault was not found
    if storagePath == nil {
        return nil
    }

    // Attempt to find Provider Path
    account.forEachPrivate(fun (path: PrivatePath, type: Type): Bool {
        if type.isSubtype(of: providerType) &&
            account.getCapability(path).borrow<&AnyResource>()?.getType()?.identifier == vaultIdentifier {
            providerPath = path
            return false
        }
        return true
    })

    // Attempt to find the Receiver Path
    account.forEachPublic(fun (path: PublicPath, type: Type): Bool {
        if type.isSubtype(of: receiverType) &&
            account.getCapability(path).borrow<&AnyResource>()?.getType()?.identifier == vaultIdentifier {
            receiverPath = path
            return false
        }
        return true
    })

    return FTVaultPaths(
        vaultIdentifier: vaultIdentifier,
        storagePath: storagePath!,
        providerPath: providerPath,
        receiverPath: receiverPath
    )
}
