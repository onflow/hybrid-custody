import "HybridCustody"

transaction(childAddress: Address) {
    prepare(acct: AuthAccount) {
        if acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) == nil {
            let m <- HybridCustody.createManager()
            acct.save(<- m, to: HybridCustody.ManagerStoragePath)

            acct.unlink(HybridCustody.ManagerPublicPath)
            acct.unlink(HybridCustody.ManagerPrivatePath)

            acct.link<&HybridCustody.Manager{HybridCustody.ManagerPrivate, HybridCustody.ManagerPublic}>(HybridCustody.PrivatePath, target: HybridCustody.ManagerStoragePath)
            acct.link<&HybridCustody.Manager{HybridCustody.ManagerPublic}>(HybridCustody.PublicPath, target: HybridCustody.ManagerStoragePath)
        }

        let inboxName = HybridCustody.getProxyIdentifierForParent(acct.address)
        let cap = acct.inbox.claim<&HybridCustody.ProxyAccount{HybridCustody.AccountPrivate, HybridCustody.AccountPublic}>(inboxName, provider: childAddress)
            ?? panic("proxy account cap not found")

        let manager = acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager no found")

        manager.addAccount(cap)
    }
}