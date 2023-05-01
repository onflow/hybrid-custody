import "HybridCustody"

pub fun main(parent: Address, child: Address): Bool {
    let acct = getAuthAccount(parent)
    let m = acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
        ?? panic("manager not found")

    let childAccount = m.borrowAccount(addr: child)
        ?? panic("child not found")

    return true
}