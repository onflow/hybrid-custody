import "HybridCustody"

// @addr - The address of the child account
// @parent - The parent account that this child is assigned to
access(all) fun main(addr: Address, parent: Address): Bool {
    let identifier = HybridCustody.getChildAccountIdentifier(parent)

    let acct = getAuthAccount<auth(Capabilities) &Account>(addr)
    var controllerID: UInt64? = nil
    for c in acct.capabilities.storage.getControllers(forPath: StoragePath(identifier: identifier)!) {
        if c.borrowType.isSubtype(of: Type<&{HybridCustody.AccountPublic}>()) {
            controllerID = c.capabilityID
            break
        }
    }

    assert(controllerID != nil, message: "could not find controller id for parent identifier")

    let controller = getAuthAccount<auth(Capabilities) &Account>(addr).capabilities.storage.getController(byCapabilityID: controllerID!)
        ?? panic("controller not found")
    let cap = controller.capability as! Capability<&{HybridCustody.AccountPublic}>
    let acctPublic = cap.borrow()!
    
    let factory = acctPublic.getCapabilityFactoryManager()
    assert(factory != nil, message: "capability factory is not valid")

    let filter = acctPublic.getCapabilityFilter()
    assert(filter != nil, message: "capability filter is not valid")

    return true
}