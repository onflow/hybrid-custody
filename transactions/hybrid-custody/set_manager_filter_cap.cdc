import "HybridCustody"
import "CapabilityFilter"

transaction(filterAddress: Address, childAddress: Address) {
    prepare(acct: AuthAccount) {
        let m = acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager not found")

        var cap = getAccount(filterAddress).capabilities.get<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)

        if cap == nil {
            cap = getAccount(filterAddress).getCapability<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        }
        assert(cap != nil, message: "manager capability not found")
        assert(cap!.check(), message: "capability filter is not valid")

        m.setManagerCapabilityFilter(cap: cap, childAddress: childAddress)
    }
}