import "HybridCustody"
import "CapabilityFilter"

transaction(filterAddress: Address, childAddress: Address) {
    prepare(acct: AuthAccount) {
        let m = acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager not found")

        let cap = getAccount(filterAddress).getCapability<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        assert(cap.check(), message: "capability filter is not valid")

        m.setManagerCapabilityFilter(cap: cap, childAddress: childAddress)
    }
}