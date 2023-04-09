import "RestrictedChildAccount"

transaction {
    prepare(acct: AuthAccount) {
        if acct.borrow<&RestrictedChildAccount.Manager>(from: RestrictedChildAccount.StoragePath) == nil {
            let m <- RestrictedChildAccount.createManager()
            acct.save(<-m, to: RestrictedChildAccount.StoragePath)
        }

        acct.unlink(RestrictedChildAccount.PublicPath)
        acct.link<&RestrictedChildAccount.Manager{RestrictedChildAccount.ManagerPublic}>(RestrictedChildAccount.PublicPath, target: RestrictedChildAccount.StoragePath)
    }
}