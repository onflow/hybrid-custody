#allowAccountLinking

import "HybridCustody"

import "CapabilityFactory"
import "CapabilityDelegator"
import "CapabilityFilter"

import "MetadataViews"

transaction(parentFilterAddress: Address?, childAccountFactoryAddress: Address, childAccountFilterAddress: Address) {
    prepare(childAcct: AuthAccount, parentAcct: AuthAccount) {
        // --------------------- End setup of child account ---------------------
        var acctCap = childAcct.getCapability<&AuthAccount>(HybridCustody.LinkedAccountPrivatePath)
        if !acctCap.check() {
            acctCap = childAcct.linkAccount(HybridCustody.LinkedAccountPrivatePath)!
        }

        if childAcct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath) == nil {
            let OwnedAccount <- HybridCustody.createChildAccount(acct: acctCap)
            childAcct.save(<-OwnedAccount, to: HybridCustody.OwnedAccountStoragePath)
        }

        // check that paths are all configured properly
        childAcct.unlink(HybridCustody.OwnedAccountPrivatePath)
        childAcct.link<&HybridCustody.OwnedAccount{HybridCustody.BorrowableAccount, HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>(HybridCustody.OwnedAccountPrivatePath, target: HybridCustody.OwnedAccountStoragePath)

        childAcct.unlink(HybridCustody.OwnedAccountPublicPath)
        childAcct.link<&HybridCustody.OwnedAccount{HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>(HybridCustody.OwnedAccountPublicPath, target: HybridCustody.OwnedAccountStoragePath)

        // --------------------- Begin setup of child account ---------------------

        // --------------------- Begin setup of parent account ---------------------
        var filter: Capability<&{CapabilityFilter.Filter}>? = nil
        if parentFilterAddress != nil {
            filter = getAccount(parentFilterAddress!).getCapability<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        }

        if parentAcct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) == nil {
            let m <- HybridCustody.createManager(filter: filter)
            parentAcct.save(<- m, to: HybridCustody.ManagerStoragePath)
        }

        parentAcct.unlink(HybridCustody.ManagerPublicPath)
        parentAcct.unlink(HybridCustody.ManagerPrivatePath)

        parentAcct.link<&HybridCustody.Manager{HybridCustody.ManagerPrivate, HybridCustody.ManagerPublic}>(HybridCustody.OwnedAccountPrivatePath, target: HybridCustody.ManagerStoragePath)
        parentAcct.link<&HybridCustody.Manager{HybridCustody.ManagerPublic}>(HybridCustody.OwnedAccountPublicPath, target: HybridCustody.ManagerStoragePath)
        // --------------------- End setup of parent account ---------------------

        // Publish account to parent
        let owned = childAcct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned account not found")

        let factory = getAccount(childAccountFactoryAddress).getCapability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath)
        assert(factory.check(), message: "factory address is not configured properly")

        let filterForChild = getAccount(childAccountFilterAddress).getCapability<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        assert(filterForChild.check(), message: "capability filter is not configured properly")

        owned.publishToParent(parentAddress: parentAcct.address, factory: factory, filter: filterForChild)

        // claim the account on the parent
        let inboxName = HybridCustody.getChildAccountIdentifier(parentAcct.address)
        let cap = parentAcct.inbox.claim<&HybridCustody.ChildAccount{HybridCustody.AccountPrivate, HybridCustody.AccountPublic, MetadataViews.Resolver}>(inboxName, provider: childAcct.address)
            ?? panic("child account cap not found")

        let manager = parentAcct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager no found")

        manager.addAccount(cap: cap)
    }
}