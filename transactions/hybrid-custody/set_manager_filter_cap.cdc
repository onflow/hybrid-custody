import "HybridCustody"
import "CapabilityFilter"

transaction(filterAddress: Address, childAddress: Address) {
    prepare(acct: AuthAccount) {
        let m = acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager not found")

        let cap = getAccount(filterAddress).capabilities.get<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
            ?? panic("capability not found")
        assert(cap.check(), message: "capability filter is not valid")

        m.setManagerCapabilityFilter(cap: cap, childAddress: childAddress)
    }
}