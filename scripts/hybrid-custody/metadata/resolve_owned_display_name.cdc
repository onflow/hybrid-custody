import "HybridCustody"
import "MetadataViews"

access(all) fun main(child: Address): String {
    let acct = getAuthAccount<auth(Storage) &Account>(child)
    let o = acct.storage.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned account not found")
    
    let d = o.resolveView(Type<MetadataViews.Display>())! as! MetadataViews.Display
    return d.name
}