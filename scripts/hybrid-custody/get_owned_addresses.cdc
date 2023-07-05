import "HybridCustody"

/// Returns a list of all ownedAccount addresses in the `parent` account's `HybridCustody.Manager`
///
pub fun main(parent: Address): [Address] {
    let acct = getAuthAccount(parent)
    let manager = acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
        ?? panic("manager not found")
    return manager.getOwnedAddresses()
}