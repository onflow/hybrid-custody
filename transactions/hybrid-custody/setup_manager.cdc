import "HybridCustody"

transaction {
    prepare(acct: AuthAccount) {
        if acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) == nil {
            let m <- HybridCustody.createManager()
            acct.save(<- m, to: HybridCustody.ManagerStoragePath)
        }

        acct.unlink(HybridCustody.ManagerPublicPath)
        acct.unlink(HybridCustody.ManagerPrivatePath)

        acct.link<&HybridCustody.Manager{HybridCustody.ManagerPrivate, HybridCustody.ManagerPublic}>(HybridCustody.ChildPrivatePath, target: HybridCustody.ManagerStoragePath)
        acct.link<&HybridCustody.Manager{HybridCustody.ManagerPublic}>(HybridCustody.ChildPublicPath, target: HybridCustody.ManagerStoragePath)
    }
}