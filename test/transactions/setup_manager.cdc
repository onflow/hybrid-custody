import "ReadOnlyChildAccount"

transaction {
    prepare(acct: AuthAccount) {
        if acct.borrow<&ReadOnlyChildAccount.Manager>(from: ReadOnlyChildAccount.StoragePath) == nil {
            let m <- ReadOnlyChildAccount.createManager()
            acct.save(<-m, to: ReadOnlyChildAccount.StoragePath)
        }
    }
}