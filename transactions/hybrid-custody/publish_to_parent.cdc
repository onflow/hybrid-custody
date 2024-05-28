import "HybridCustody"
import "CapabilityFactory"
import "CapabilityFilter"
import "CapabilityDelegator"

transaction(parent: Address, factoryAddress: Address, filterAddress: Address) {
    prepare(acct: auth(Storage) &Account) {
        let owned = acct.storage.borrow<auth(HybridCustody.Owner) &HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned account not found")

        let factory = getAccount(factoryAddress).capabilities.get<&CapabilityFactory.Manager>(CapabilityFactory.PublicPath)
        assert(factory.check(), message: "factory address is not configured properly")

        let filter = getAccount(filterAddress).capabilities.get<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        assert(filter.check(), message: "capability filter is not configured properly")

        owned.publishToParent(parentAddress: parent, factory: factory, filter: filter)
    }
}