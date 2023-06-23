import "HybridCustody"
import "MetadataViews"

pub fun main(child: Address): String {
    let acct = getAuthAccount(child)
    let c = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.ChildStoragePath)
            ?? panic("child account not found")
    
    let d = c.resolveView(Type<MetadataViews.Display>())! as! MetadataViews.Display
    return d.name
}