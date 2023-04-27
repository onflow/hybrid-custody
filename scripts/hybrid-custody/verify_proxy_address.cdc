import "HybridCustody"

/*
Verify that a child address borrowed as a proxy matches the address
it is mapped to in the account manager
*/
pub fun main(parent: Address, child: Address) {
    let acct = getAuthAccount(parent)
    let m = acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
        ?? panic("manager does not exist")

    let childAcct = m.borrowAccount(addr: child) ?? panic("child account not found")
    assert(childAcct.getAddress() == child, message: "addresses do not match")
}