import "HybridCustody"
import "CapabilityFactory"

transaction(parent: Address, factoryAddress: Address) {
    prepare(acct: auth(Storage) &Account) {
        let cap = getAccount(factoryAddress).capabilities.get<&{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath)
            ?? panic("capability factory was nil")
        
        let ownedAccount = acct.storage.borrow<auth(HybridCustody.Owner) &{HybridCustody.OwnedAccountPrivate}>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned account not found")
        ownedAccount.setCapabilityFactoryForParent(parent: parent, cap: cap)
    }
}