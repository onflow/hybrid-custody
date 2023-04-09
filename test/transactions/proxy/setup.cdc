import "CapabilityProxy"

transaction {
    prepare(acct: AuthAccount) {
        if acct.borrow<&CapabilityProxy.Proxy>(from: CapabilityProxy.StoragePath) == nil {
            let proxy <- CapabilityProxy.createProxy()
            acct.save(<-proxy, to: CapabilityProxy.StoragePath)
        }

        acct.unlink(CapabilityProxy.PublicPath)
        acct.unlink(CapabilityProxy.PrivatePath)

        acct.link<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic}>(CapabilityProxy.PublicPath, target: CapabilityProxy.StoragePath)
        acct.link<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>(CapabilityProxy.PrivatePath, target: CapabilityProxy.StoragePath)
    }
}