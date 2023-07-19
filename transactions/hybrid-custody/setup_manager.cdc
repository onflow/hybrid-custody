import "HybridCustody"
import "CapabilityFilter"

transaction(filterAddress: Address?, filterPath: PublicPath?) {
    prepare(acct: AuthAccount) {
        var filter: Capability<&{CapabilityFilter.Filter}>? = nil
        if filterAddress != nil && filterPath != nil {
            filter = getAccount(filterAddress!).getCapability<&{CapabilityFilter.Filter}>(filterPath!)
        }

        if acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) == nil {
            let m <- HybridCustody.createManager(filter: filter)
            acct.save(<- m, to: HybridCustody.ManagerStoragePath)
        }

        acct.capabilities.unpublish(HybridCustody.ManagerPublicPath)
        let publicCap = acct.capabilities.storage.issue<&HybridCustody.Manager{HybridCustody.ManagerPublic}>(HybridCustody.ManagerStoragePath)
        acct.capabilities.publish(publicCap, at: HybridCustody.ManagerPublicPath)
    }
}
