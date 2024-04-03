import "HybridCustody"

access(all) fun main(addr: Address): Address? {
    let acct = getAuthAccount<auth(BorrowValue) &Account>(addr)
    let o = acct.storage.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
        ?? panic("owned account missing")
    
    return o.getPendingOwner()
}