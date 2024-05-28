import "FungibleToken"
import "HybridCustody"

/// Queries for $FLOW balance of a given Address and all its associated accounts
///
access(all) fun main(address: Address): {Address: UFix64} {

    // Get the balance for the given address
    let balances: {Address: UFix64} = { address: getAccount(address).balance }
    // Tracking Addresses we've come across to prevent overwriting balances more efficiently than checking return mapping
    let seen: [Address] = [address]
    
    /* Iterate over any associated accounts */ 
    //
    if let managerRef = getAuthAccount<auth(Storage) &Account>(address).storage.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) {
        
        for childAccount in managerRef.getChildAddresses() {
            balances.insert(key: childAccount, getAccount(childAccount).balance)
            seen.append(childAccount)
        }

        for ownedAccount in managerRef.getOwnedAddresses() {
            if seen.contains(ownedAccount) == false {
                balances.insert(key: ownedAccount, getAccount(ownedAccount).balance)
                seen.append(ownedAccount)
            }
        }
    }

    return balances 
}