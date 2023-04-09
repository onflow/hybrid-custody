#allowAccountLinking

import "RestrictedChildAccount"
import "CapabilityProxy"
import "MetadataViews"

transaction(parent: Address, name: String, description: String, thumbnail: String) {
    let authAccountCap: Capability<&AuthAccount>

    prepare(acct: AuthAccount) {
        // Get the AuthAccount Capability, linking if necessary
        if !acct.getCapability<&AuthAccount>(RestrictedChildAccount.AuthAccountCapabilityPath).check() {
            self.authAccountCap = acct.linkAccount(RestrictedChildAccount.AuthAccountCapabilityPath)!
        } else {
            self.authAccountCap = acct.getCapability<&AuthAccount>(RestrictedChildAccount.AuthAccountCapabilityPath)
        }

        let a <- RestrictedChildAccount.createRestrictedAccount(
            acctCap: self.authAccountCap,
            name: name,
            thumbnail: MetadataViews.HTTPFile(url: thumbnail),
            description: description
        )

        if acct.borrow<&CapabilityProxy>(from: CapabilityProxy.StoragePath) == nil {
            let proxy <- CapabilityProxy.createProxy()
            acct.save(<-proxy, to: CapabilityProxy.StoragePath)
        }

        if !acct.getCapability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>(CapabilityProxy.PrivatePath).check() {
            acct.unlink(CapabilityProxy.PrivatePath)
            acct.link<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>(CapabilityProxy.PrivatePath, target: CapabilityProxy.StoragePath)
        }

        let proxy = acct.getCapability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>(CapabilityProxy.PrivatePath)
        assert(proxy.check(), message: "failed to configure capability proxy")

        acct.link<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic}>(CapabilityProxy.PublicPath, target: CapabilityProxy.StoragePath)
        acct.link<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>(CapabilityProxy.PrivatePath, target: CapabilityProxy.StoragePath)

        let s <- RestrictedChildAccount.wrapAccount(<- a, proxy: proxy)

        // we need to save the wrapped account so that our parent can redeem it
        acct.save(<-s, to: RestrictedChildAccount.SharedAccountStoragePath)
        acct.link<&RestrictedChildAccount.SharedAccount>(RestrictedChildAccount.SharedAccountPrivatePath, target: RestrictedChildAccount.SharedAccountStoragePath)
        let cap = acct.getCapability<&RestrictedChildAccount.SharedAccount>(RestrictedChildAccount.SharedAccountPrivatePath)

        // Publish for the specified Address
        acct.inbox.publish(cap, name: RestrictedChildAccount.InboxName, recipient: parent)
    }
}