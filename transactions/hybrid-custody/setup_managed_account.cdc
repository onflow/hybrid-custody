#allowAccountLinking

import "HybridCustody"

import "CapabilityFactory"
import "CapabilityProxy"
import "CapabilityFilter"

transaction(factoryAddress: Address, filterAddress: Address) {
    prepare(acct: AuthAccount) {
        var acctCap = acct.getCapability<&AuthAccount>(HybridCustody.LinkedAccountPrivatePath)
        if !acctCap.check() {
            acctCap = acct.linkAccount(HybridCustody.LinkedAccountPrivatePath)!
        }

        let factoryCap = getAccount(factoryAddress).getCapability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath)
        assert(factoryCap.check(), message: "factory address is not configured properly")

        let filterCap = getAccount(filterAddress).getCapability<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        assert(filterCap.check(), message: "capability filter is not configured properly")

        if acct.borrow<&HybridCustody.ChildAccount>(from: HybridCustody.StoragePath) == nil {
            let proxy <- CapabilityProxy.createProxy()
            let ChildAccount <- HybridCustody.createChildAccount(acct: acctCap, factory: factoryCap, filter: filterCap, proxy: <- proxy)
            acct.save(<-ChildAccount, to: HybridCustody.StoragePath)
        }

        // check that paths are all configured properly
        acct.unlink(HybridCustody.PrivatePath)
        acct.link<&HybridCustody.ChildAccount{HybridCustody.AccountPrivate}>(HybridCustody.PrivatePath, target: HybridCustody.StoragePath)

        acct.unlink(HybridCustody.PublicPath)
        acct.link<&HybridCustody.ChildAccount{HybridCustody.AccountPublic}>(HybridCustody.PublicPath, target: HybridCustody.StoragePath)
    }
}