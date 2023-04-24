import "HybridCustody"

pub fun main(addr: Address): Address? {
    let acct = getAuthAccount(addr)
    let c = acct.borrow<&HybridCustody.ChildAccount>(from: HybridCustody.ChildStoragePath)
        ?? panic("child account missing")
    
    return c.getOwner()
}