import "HybridCustody"

/// Returns whether the given Address has a HybridCustod.Manager with child accounts or not
///
pub fun main(parent: Address): Bool {
    let acct = getAuthAccount(parent)
    if let manager = acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) {
        return manager.getAddresses().length > 0
    }
    return false
}
