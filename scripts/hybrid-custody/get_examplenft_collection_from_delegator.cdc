import "HybridCustody"
import "ExampleNFT"

pub fun main(parent: Address, child: Address, isPublic: Bool) {
    let m = getAuthAccount(parent).borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
        ?? panic("manager not found")
    let acct = m.borrowAccount(addr: child)
        ?? panic("child account not found in manager")

    let t = Type<Capability<&ExampleNFT.Collection>>()

    let cap = (isPublic ? acct.getPublicCapFromDelegator(type: t) : acct.getPrivateCapFromDelegator(type: t))
        ?? panic("capability not found")
    
    assert(cap.getType() == t, message: "mismatched capability types")
}