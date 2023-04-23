import "HybridCustody"

pub fun main(addr: Address): [AnyStruct] {
    let acct = getAuthAccount(addr)
    let manager = acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
        ?? panic("manager not found")
    return manager.getIDs()
}