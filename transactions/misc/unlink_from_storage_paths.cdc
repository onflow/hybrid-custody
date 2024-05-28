transaction(storagePaths: [StoragePath]) {
    prepare(acct: auth(Capabilities) &Account) {
        for storagePath in storagePaths {
            let controllers = acct.capabilities.storage.getControllers(forPath: storagePath)
            for con in controllers {
                acct.capabilities.storage.getController(byCapabilityID: con.capabilityID)?.delete()
            }
        }
    }
}