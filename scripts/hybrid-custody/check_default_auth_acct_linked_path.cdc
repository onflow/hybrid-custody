import "HybridCustody"

pub fun main(addr: Address): Bool {
    let acct = getAuthAccount(addr)
    return acct.getCapability<&AuthAccount>(HybridCustody.LinkedAccountPrivatePath).check()
}