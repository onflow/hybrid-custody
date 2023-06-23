import "HybridCustody"

pub fun main(child: Address): [Address] {
    let acct = getAuthAccount(child)
    let m = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
        ?? panic("owned account not found")
    return  m.getParentsAddresses() 
}