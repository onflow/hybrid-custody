import "FungibleToken"
import "HybridCustody"

/// Returns the balance of the object (presumably a FungibleToken Vault) at the given path in the specified account
///
access(all) fun getVaultBalance(_ address: Address, _ balancePath: PublicPath): UFix64 {
    let cap = getAccount(address).capabilities.get<&{FungibleToken.Balance}>(balancePath)
    if cap == nil {
        return 0.0
    }

    return cap!.borrow()?.balance ?? 0.0
}

/// Queries for FT.Vault balance of all FT.Vaults at given path in the specified account and all of its associated accounts
///
access(all) fun main(address: Address, balancePath: PublicPath): {Address: UFix64} {

    // Get the balance for the given address
    let balances: {Address: UFix64} = { address: getVaultBalance(address, balancePath) }
    // Tracking Addresses we've come across to prevent overwriting balances more efficiently than checking return mapping
    let seen: [Address] = [address]
    
    /* Iterate over any associated accounts */ 
    //
    if let managerRef = getAuthAccount<auth(Storage) &Account>(address).storage.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) {
        
        for childAccount in managerRef.getChildAddresses() {
            balances.insert(key: childAccount, getVaultBalance(address, balancePath))
            seen.append(childAccount)
        }

        for ownedAccount in managerRef.getOwnedAddresses() {
            if seen.contains(ownedAccount) == false {
                balances.insert(key: ownedAccount, getVaultBalance(address, balancePath))
                seen.append(ownedAccount)
            }
        }
    }

    return balances 
}
