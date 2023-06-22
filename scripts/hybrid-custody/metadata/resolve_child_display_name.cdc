import "HybridCustody"
import "MetadataViews"

pub fun main(parent: Address, child: Address): String {
    let acct = getAuthAccount(parent)
    let m = acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager not found")

    let c = m.borrowAccount(addr: child) ?? panic("child not found")
    
    let d = c.resolveView(Type<MetadataViews.Display>())! as! MetadataViews.Display
    return d.name
}