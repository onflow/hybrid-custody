#allowAccountLinking

import "RestrictedChildAccount"
import "CapabilityProxy"
import "CapabilityFilter"

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

        // ------------ BEGIN Setup CapabilityProxy
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
        // ------------ END Setup CapabilityProxy

        // ------------ BEGIN Setup CapabilityFilter
        if acct.borrow<&{CapabilityFilter.Filter}>(from: CapabilityFilter.StoragePath) == nil {
            let filter <- CapabilityFilter.create(Type<@CapabilityFilter.AllowAllFilter>())
            acct.save(<-filter, to: CapabilityFilter.StoragePath)
        }

        if !acct.getCapability<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath).check() {
            acct.unlink(CapabilityFilter.PublicPath)
            acct.link<&CapabilityFilter.AllowAllFilter{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath, target: CapabilityFilter.StoragePath)
        }

        let filterCap = acct.getCapability<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        assert(filterCap.check(), message: "failed to configure capability filter")
        // ------------ END Setup CapabilityFilter

        let a <- RestrictedChildAccount.createRestrictedAccount(
            acctCap: self.authAccountCap,
            name: name,
            thumbnail: MetadataViews.HTTPFile(url: thumbnail),
            description: description,
            proxy: proxy,
            filter: filterCap
        )

        let s <- RestrictedChildAccount.wrapAccount(<- a)

        // we need to save the wrapped account so that our parent can redeem it
        acct.save(<-s, to: RestrictedChildAccount.SharedAccountStoragePath)
        acct.link<&RestrictedChildAccount.SharedAccount>(RestrictedChildAccount.SharedAccountPrivatePath, target: RestrictedChildAccount.SharedAccountStoragePath)
        let cap = acct.getCapability<&RestrictedChildAccount.SharedAccount>(RestrictedChildAccount.SharedAccountPrivatePath)

        // Publish for the specified Address
        acct.inbox.publish(cap, name: RestrictedChildAccount.InboxName, recipient: parent)
    }
}