#allowAccountLinking

import "HybridCustody"

import "CapabilityFactory"
import "CapabilityDelegator"
import "CapabilityFilter"

import "MetadataViews"

transaction(name: String, desc: String, thumbnailURL: String) {
    prepare(acct: AuthAccount) {
        var acctCap = acct.getCapability<&AuthAccount>(HybridCustody.LinkedAccountPrivatePath)
        if !acctCap.check() {
            acctCap = acct.linkAccount(HybridCustody.LinkedAccountPrivatePath)!
        }

        if acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath) == nil {
            let OwnedAccount <- HybridCustody.createChildAccount(acct: acctCap)
            acct.save(<-OwnedAccount, to: HybridCustody.OwnedAccountStoragePath)
        }

        // check that paths are all configured properly
        acct.unlink(HybridCustody.OwnedAccountPrivatePath)
        acct.link<&HybridCustody.OwnedAccount{HybridCustody.BorrowableAccount, HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>(HybridCustody.OwnedAccountPrivatePath, target: HybridCustody.OwnedAccountStoragePath)

        acct.unlink(HybridCustody.OwnedAccountPublicPath)
        acct.link<&HybridCustody.OwnedAccount{HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>(HybridCustody.OwnedAccountPublicPath, target: HybridCustody.OwnedAccountStoragePath)

        let owned = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)!

        let thumbnail = MetadataViews.HTTPFile(url: thumbnailURL)
        let display = MetadataViews.Display(name: name, description: desc, thumbnail: thumbnail)
        owned.setDisplay(display)
    }
}
 