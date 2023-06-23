import "HybridCustody"

pub fun main(addr: Address): Address? {
    let acct = getAuthAccount(addr)
    let o = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
        ?? panic("owned account missing")
    
    return o.getPendingOwner()
}