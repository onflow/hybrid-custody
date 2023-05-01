import "HybridCustody"

pub fun main(child: Address, parent: Address): Bool {
    let acct = getAuthAccount(child)
    let m = acct.borrow<&HybridCustody.ChildAccount>(from: HybridCustody.ChildStoragePath)
        ?? panic("child account not found")

    return m.getRedeemedStatus(addr: parent) ?? panic("no status found")
}