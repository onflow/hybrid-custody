import "RestrictedChildAccount"

pub fun main(addr: Address): Bool {
    if let m = getAuthAccount(addr).borrow<&RestrictedChildAccount.Manager>(from: RestrictedChildAccount.StoragePath) {
        return true
    }

    return false
}