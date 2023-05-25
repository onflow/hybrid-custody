import "HybridCustody"

import "FungibleToken"
import "ExampleToken"

// Verify that a child address borrowed as a proxy will let the parent borrow an FT provider capability
pub fun main(parent: Address, child: Address) {
    let acct = getAuthAccount(parent)
    let m = acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
        ?? panic("manager does not exist")

    let childAcct = m.borrowAccount(addr: child) ?? panic("child account not found")
    let nakedCap = childAcct.getCapability(path: /private/exampleTokenProvider, type: Type<&{FungibleToken.Provider}>())
				?? panic("Could not borrow reference to the owner's Vault!")
    let providerCap = nakedCap as! Capability<&{FungibleToken.Provider}>
    assert(providerCap.check(), message: "invalid provider capability")
    providerCap.borrow()!
}