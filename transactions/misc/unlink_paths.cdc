transaction(paths: [CapabilityPath]) {
    prepare(acct: AuthAccount) {
        for p in paths {
            acct.unlink(p)
        }
    }
}