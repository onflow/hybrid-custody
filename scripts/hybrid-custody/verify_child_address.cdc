import "HybridCustody"

/*
Verify that a owned address borrowed as a child matches the address
it is mapped to in the account manager
*/
access(all) fun main(parent: Address, child: Address) {
    let acct = getAuthAccount<auth(BorrowValue) &Account>(parent)
    let m = acct.storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
        ?? panic("manager does not exist")

    let childAcct = m.borrowAccount(addr: child) ?? panic("child account not found")
    assert(childAcct.getAddress() == child, message: "addresses do not match")
}