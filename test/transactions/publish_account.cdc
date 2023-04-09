#allowAccountLinking

import "RestrictedChildAccount"
import "MetadataViews"

transaction(parent: Address, name: String, description: String, thumbnail: String) {
    let authAccountCap: Capability<&AuthAccount>

    prepare(signer: AuthAccount) {
        // Get the AuthAccount Capability, linking if necessary
        if !signer.getCapability<&AuthAccount>(RestrictedChildAccount.AuthAccountCapabilityPath).check() {
            self.authAccountCap = signer.linkAccount(RestrictedChildAccount.AuthAccountCapabilityPath)!
        } else {
            self.authAccountCap = signer.getCapability<&AuthAccount>(RestrictedChildAccount.AuthAccountCapabilityPath)
        }

        let a <- RestrictedChildAccount.createRestrictedAccount(
            acctCap: self.authAccountCap,
            name: name,
            thumbnail: MetadataViews.HTTPFile(url: thumbnail),
            description: description
        )

        let s <- RestrictedChildAccount.wrapAccount(<- a)

        // we need to save the wrapped account so that our parent can redeem it
        signer.save(<-s, to: RestrictedChildAccount.SharedAccountStoragePath)
        signer.link<&RestrictedChildAccount.SharedAccount>(RestrictedChildAccount.SharedAccountPrivatePath, target: RestrictedChildAccount.SharedAccountStoragePath)
        let cap = signer.getCapability<&RestrictedChildAccount.SharedAccount>(RestrictedChildAccount.SharedAccountPrivatePath)

        // Publish for the specified Address
        signer.inbox.publish(cap, name: RestrictedChildAccount.InboxName, recipient: parent)
    }
}