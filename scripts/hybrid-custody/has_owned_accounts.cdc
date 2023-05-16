import "HybridCustody"

/// Returns whether the given Address has a HybridCustod.Manager with owned accounts or not
///
pub fun main(parent: Address): Bool {
    let acct = getAuthAccount(parent)
    if let manager = acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) {
        return manager.getOwnedAddresses().length > 0
    }
    return false
}
