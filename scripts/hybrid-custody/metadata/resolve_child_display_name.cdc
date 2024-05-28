import "HybridCustody"
import "MetadataViews"

access(all) fun main(parent: Address, child: Address): String {
    let acct = getAuthAccount<auth(Storage) &Account>(parent)
    let m = acct.storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager not found")

    let c = m.borrowAccount(addr: child) ?? panic("child not found")

    let tmp = c.resolveView(Type<MetadataViews.Display>()) ?? panic("unable to resolve metadata display")
    
    let d = tmp as! MetadataViews.Display
    return d.name
}