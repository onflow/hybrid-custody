import ReadOnlyChildAccount from "ReadOnlyChildAccount"

pub fun main(addr: Address): Bool {
    if let m = getAuthAccount(addr).borrow<&ReadOnlyChildAccount.Manager>(from: ReadOnlyChildAccount.StoragePath) {
        return true
    }

    return false
}