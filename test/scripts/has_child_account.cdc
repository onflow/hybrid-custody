import "RestrictedChildAccount"
import "MetadataViews"

pub fun main(addr: Address, childAddress: Address, name: String): Bool {
    let acct = getAuthAccount(addr)
    let manager = acct.borrow<&RestrictedChildAccount.Manager>(from: RestrictedChildAccount.StoragePath) ?? panic("manager not found")

    let child = manager.borrowByNamePublic(name: name) ?? panic("child not found")
    let display = child.resolveView(Type<MetadataViews.Display>())! as! MetadataViews.Display

    return display.name == name && child.getAccountAddress() == childAddress
}