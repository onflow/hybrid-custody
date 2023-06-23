import "HybridCustody"

pub fun main(child: Address): [Address] {
    let acct = getAuthAccount(child)
    let o = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
        ?? panic("owned account not found")
    return  o.getParentsAddresses() 
}