import "HybridCustody"
import "CapabilityFilter"

transaction(parent: Address, factoryAddress: Address) {
    prepare(acct: auth(Storage) &Account) {
        let cap = getAccount(factoryAddress).capabilities.get<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        
        let ownedAccount = acct.storage.borrow<auth(HybridCustody.Owner) &{HybridCustody.OwnedAccountPrivate}>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned account not found")
        ownedAccount.setCapabilityFilterForParent(parent: parent, cap: cap)
    }
}