#allowAccountLinking

import "HybridCustody"

import "CapabilityFactory"
import "CapabilityProxy"
import "CapabilityFilter"

import "MetadataViews"

transaction(name: String, desc: String, thumbnailURL: String) {
    prepare(acct: AuthAccount) {
        var acctCap = acct.getCapability<&AuthAccount>(HybridCustody.LinkedAccountPrivatePath)
        if !acctCap.check() {
            acctCap = acct.linkAccount(HybridCustody.LinkedAccountPrivatePath)!
        }

        if acct.borrow<&HybridCustody.ChildAccount>(from: HybridCustody.ChildStoragePath) == nil {
            let ChildAccount <- HybridCustody.createChildAccount(acct: acctCap)
            acct.save(<-ChildAccount, to: HybridCustody.ChildStoragePath)
        }

        // check that paths are all configured properly
        acct.unlink(HybridCustody.ChildPrivatePath)
        acct.link<&HybridCustody.ChildAccount{HybridCustody.BorrowableAccount, HybridCustody.ChildAccountPublic, HybridCustody.ChildAccountPrivate}>(HybridCustody.ChildPrivatePath, target: HybridCustody.ChildStoragePath)

        acct.unlink(HybridCustody.ChildPublicPath)
        acct.link<&HybridCustody.ChildAccount{HybridCustody.ChildAccountPublic}>(HybridCustody.ChildPublicPath, target: HybridCustody.ChildStoragePath)

        let child = acct.borrow<&HybridCustody.ChildAccount>(from: HybridCustody.ChildStoragePath)!

        let thumbnail = MetadataViews.HTTPFile(url: thumbnailURL)
        let display = MetadataViews.Display(name: name, description: desc, thumbnail: thumbnail)
        child.setDisplay(display)
    }
}
 