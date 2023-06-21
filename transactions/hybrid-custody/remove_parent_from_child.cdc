import "HybridCustody"

transaction(parent: Address) {
    prepare(acct: AuthAccount) {
        let child = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.ChildStoragePath)
            ?? panic("child not found")

        child.removeParent(parent: parent)

        let manager = getAccount(parent).getCapability<&HybridCustody.Manager{HybridCustody.ManagerPublic}>(HybridCustody.ManagerPublicPath)
            .borrow() ?? panic("manager not found")
        let children = manager.getChildAddresses()
        assert(!children.contains(acct.address), message: "removed child is still in manager resource")
    }
}