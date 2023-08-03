import "HybridCustody"
import "ExampleNFT"

pub fun main(parent: Address, child: Address, isPublic: Bool) {
    let m = getAuthAccount(parent).borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
        ?? panic("manager not found")
    let acct = m.borrowAccount(addr: child)
        ?? panic("child account not found in manager")

    let t = Type<Capability<&ExampleNFT.Collection>>()

    let delegatorGetter = acct.borrowDelegatorCapabilityGetter()
    // Note(by Bohao): Actually, there is no need to use `ispublic`. You can directly use `delegatorGetter.getCapability`.
    let cap = (isPublic ? delegatorGetter.getPublicCapability(type: t) : delegatorGetter.getCapability(type: t))
        ?? panic("capability not found")

    assert(cap.getType() == t, message: "mismatched capability types")
}
