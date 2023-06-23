import "HybridCustody"

pub fun main(child: Address): {Address: Bool} {
    let acct = getAuthAccount(child)
    let m = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
        ?? panic("owned account not found")

    return m.getParentStatuses()
}