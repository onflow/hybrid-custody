import "HybridCustody"
import "CapabilityFilter"

transaction(filterAddress: Address, childAddress: Address) {
    prepare(acct: auth(Storage) &Account) {
        let m = acct.storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager not found")

        let cap = getAccount(filterAddress).capabilities.get<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        assert(cap.check(), message: "capability filter is not valid")

        m.setManagerCapabilityFilter(cap: cap, childAddress: childAddress)
    }
}