import "HybridCustody"
import "MetadataViews"

pub fun main(child: Address): String {
    let acct = getAuthAccount(child)
    let o = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned account not found")
    
    let d = o.resolveView(Type<MetadataViews.Display>())! as! MetadataViews.Display
    return d.name
}