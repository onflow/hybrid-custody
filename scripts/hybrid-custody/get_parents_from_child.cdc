import "HybridCustody"

access(all) fun main(child: Address): {Address: Bool} {
    let acct = getAuthAccount<auth(BorrowValue) &Account>(child)
    let o = acct.storage.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
        ?? panic("OwnedAccount not found in account with address ".concat(child.toString()))

    return o.getParentStatuses()
}