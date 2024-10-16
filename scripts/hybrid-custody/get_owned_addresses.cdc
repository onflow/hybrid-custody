import "HybridCustody"

/// Returns a list of all ownedAccount addresses in the `parent` account's `HybridCustody.Manager`
///
access(all) fun main(parent: Address): [Address] {
    let acct = getAuthAccount<auth(BorrowValue) &Account>(parent)
    let manager = acct.storage.borrow<&HybridCustody.Manager>(
            from: HybridCustody.ManagerStoragePath
        ) ?? panic("A HybridCustody Manager has not been initialized in account with address ".concat(parent.toString()))
    return manager.getOwnedAddresses()
}
