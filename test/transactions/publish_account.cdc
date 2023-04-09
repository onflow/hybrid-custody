#allowAccountLinking

import "ReadOnlyChildAccount"
import "MetadataViews"

transaction(parent: Address, name: String, description: String, thumbnail: String) {
    let authAccountCap: Capability<&AuthAccount>

    prepare(signer: AuthAccount) {
        // Get the AuthAccount Capability, linking if necessary
        if !signer.getCapability<&AuthAccount>(ReadOnlyChildAccount.AuthAccountCapabilityPath).check() {
            self.authAccountCap = signer.linkAccount(ReadOnlyChildAccount.AuthAccountCapabilityPath)!
        } else {
            self.authAccountCap = signer.getCapability<&AuthAccount>(ReadOnlyChildAccount.AuthAccountCapabilityPath)
        }

        let a <- ReadOnlyChildAccount.createReadOnlyAccount(
            acctCap: self.authAccountCap,
            name: name,
            thumbnail: MetadataViews.HTTPFile(url: thumbnail),
            description: description
        )

        let s <- ReadOnlyChildAccount.wrapAccount(<- a)

        // we need to save the wrapped account so that our parent can redeem it
        signer.save(<-s, to: ReadOnlyChildAccount.SharedAccountStoragePath)
        signer.link<&ReadOnlyChildAccount.SharedAccount>(ReadOnlyChildAccount.SharedAccountPrivatePath, target: ReadOnlyChildAccount.SharedAccountStoragePath)
        let cap = signer.getCapability<&ReadOnlyChildAccount.SharedAccount>(ReadOnlyChildAccount.SharedAccountPrivatePath)

        // Publish for the specified Address
        signer.inbox.publish(cap, name: ReadOnlyChildAccount.InboxName, recipient: parent)
    }
}