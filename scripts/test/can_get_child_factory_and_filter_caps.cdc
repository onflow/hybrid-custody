import "HybridCustody"

// @addr - The address of the child account
// @parent - The parent account that this child is assigned to
pub fun main(addr: Address, parent: Address): Bool {
    let identifier = HybridCustody.getChildAccountIdentifier(parent)
    let path = PrivatePath(identifier: identifier) ?? panic("invalid public path identifier for parent address")

    let acctPublic = getAuthAccount(addr).getCapability<&HybridCustody.ChildAccount{HybridCustody.AccountPublic}>(path)
        .borrow() ?? panic("account public not found")
    
    let filter = acctPublic.getCapabilityFactory()
    assert(filter.check(), message: "capability filter is not valid")

    let factory = acctPublic.getCapabilityFilter()
    assert(factory.check(), message: "capability factory is not valid")

    return true
}