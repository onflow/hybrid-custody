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

        if acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.ChildStoragePath) == nil {
            let OwnedAccount <- HybridCustody.createChildAccount(acct: acctCap)
            acct.save(<-OwnedAccount, to: HybridCustody.ChildStoragePath)
        }

        // check that paths are all configured properly
        acct.unlink(HybridCustody.ChildPrivatePath)
        acct.link<&HybridCustody.OwnedAccount{HybridCustody.BorrowableAccount, HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>(HybridCustody.ChildPrivatePath, target: HybridCustody.ChildStoragePath)

        acct.unlink(HybridCustody.ChildPublicPath)
        acct.link<&HybridCustody.OwnedAccount{HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>(HybridCustody.ChildPublicPath, target: HybridCustody.ChildStoragePath)

        let child = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.ChildStoragePath)!

        let thumbnail = MetadataViews.HTTPFile(url: thumbnailURL)
        let display = MetadataViews.Display(name: name, description: desc, thumbnail: thumbnail)
        child.setDisplay(display)
    }
}
 