#allowAccountLinking

import "HybridCustody"

import "CapabilityFactory"
import "CapabilityDelegator"
import "CapabilityFilter"

import "MetadataViews"
import "ViewResolver"

transaction(parentFilterAddress: Address?, childAccountFactoryAddress: Address, childAccountFilterAddress: Address) {
    prepare(childAcct: auth(Storage, Capabilities) &Account, parentAcct: auth(Storage, Capabilities, Inbox) &Account) {
        // --------------------- Begin setup of child account ---------------------
        var optCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>? = nil
        let t = Type<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>()
        for c in childAcct.capabilities.account.getControllers() {
            if c.borrowType.isSubtype(of: t) {
                optCap = c.capability as! Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>
                break
            }
        }

        if optCap == nil {
            optCap = childAcct.capabilities.account.issue<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>()
        }
        let acctCap = optCap ?? panic("failed to get account capability")

        if childAcct.storage.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath) == nil {
            let ownedAccount <- HybridCustody.createOwnedAccount(acct: acctCap)
            childAcct.storage.save(<-ownedAccount, to: HybridCustody.OwnedAccountStoragePath)
        }

        for c in childAcct.capabilities.storage.getControllers(forPath: HybridCustody.OwnedAccountStoragePath) {
            c.delete()
        }

        // configure capabilities
        childAcct.capabilities.storage.issue<&{HybridCustody.BorrowableAccount, HybridCustody.OwnedAccountPublic, ViewResolver.Resolver}>(HybridCustody.OwnedAccountStoragePath)
        childAcct.capabilities.publish(
            childAcct.capabilities.storage.issue<&{HybridCustody.OwnedAccountPublic, ViewResolver.Resolver}>(HybridCustody.OwnedAccountStoragePath),
            at: HybridCustody.OwnedAccountPublicPath
        )

        // --------------------- End setup of child account ---------------------

        // --------------------- Begin setup of parent account ---------------------
        var filter: Capability<&{CapabilityFilter.Filter}>? = nil
        if parentFilterAddress != nil {
            filter = getAccount(parentFilterAddress!).capabilities.get<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
                ?? panic("parent filter address provided but it was not valid")
        }

        if parentAcct.storage.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) == nil {
            let m <- HybridCustody.createManager(filter: filter)
            parentAcct.storage.save(<- m, to: HybridCustody.ManagerStoragePath)
        }

        for c in parentAcct.capabilities.storage.getControllers(forPath: HybridCustody.ManagerStoragePath) {
            c.delete()
        }

        parentAcct.capabilities.publish(
            parentAcct.capabilities.storage.issue<&{HybridCustody.ManagerPublic}>(HybridCustody.ManagerStoragePath),
            at: HybridCustody.ManagerPublicPath
        )
        parentAcct.capabilities.storage.issue<auth(HybridCustody.Manage) &{HybridCustody.ManagerPrivate, HybridCustody.ManagerPublic}>(HybridCustody.ManagerStoragePath)

        // --------------------- End setup of parent account ---------------------

        // Publish account to parent
        let owned = childAcct.storage.borrow<auth(HybridCustody.Owner) &HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned account not found")

        let factory = getAccount(childAccountFactoryAddress).capabilities.get<&{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath)
            ?? panic("child account factory capability was nil")
        assert(factory.check(), message: "factory address is not configured properly")

        let filterForChild = getAccount(childAccountFilterAddress).capabilities.get<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
            ?? panic("child account filter capability was nil")
        assert(filterForChild.check(), message: "capability filter is not configured properly")

        owned.publishToParent(parentAddress: parentAcct.address, factory: factory, filter: filterForChild)

        // claim the account on the parent
        let inboxName = HybridCustody.getChildAccountIdentifier(parentAcct.address)
        let cap = parentAcct.inbox.claim<auth(HybridCustody.Child) &{HybridCustody.AccountPrivate, HybridCustody.AccountPublic, ViewResolver.Resolver}>(inboxName, provider: childAcct.address)
            ?? panic("child account cap not found")

        let manager = parentAcct.storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager no found")

        manager.addAccount(cap: cap)
    }
}