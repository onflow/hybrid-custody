#allowAccountLinking

import "HybridCustody"

import "CapabilityFactory"
import "CapabilityDelegator"
import "CapabilityFilter"

import "MetadataViews"

transaction(parentFilterAddress: Address?, childAccountFactoryAddress: Address, childAccountFilterAddress: Address) {
    prepare(childAcct: AuthAccount, parentAcct: AuthAccount) {
        // --------------------- Begin setup of child account ---------------------
        var acctCap = childAcct.capabilities.account.issue<&AuthAccount>()

        if childAcct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath) == nil {
            let ownedAccount <- HybridCustody.createOwnedAccount(acct: acctCap)
            childAcct.save(<-ownedAccount, to: HybridCustody.OwnedAccountStoragePath)
        }

        // check that paths are all configured properly
        childAcct.capabilities.unpublish(HybridCustody.OwnedAccountPublicPath)
        let ownedPublicCap = childAcct.capabilities.storage.issue<&HybridCustody.OwnedAccount{HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>(HybridCustody.OwnedAccountStoragePath)
        childAcct.capabilities.publish(ownedPublicCap, at: HybridCustody.OwnedAccountPublicPath)
        // --------------------- End setup of child account ---------------------

        // --------------------- Begin setup of parent account ---------------------
        var filter: Capability<&{CapabilityFilter.Filter}>? = nil
        if parentFilterAddress != nil {
            filter = getAccount(parentFilterAddress!).capabilities.get<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        }

        if parentAcct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) == nil {
            let m <- HybridCustody.createManager(filter: filter)
            parentAcct.save(<- m, to: HybridCustody.ManagerStoragePath)
        }

        parentAcct.capabilities.unpublish(HybridCustody.ManagerPublicPath)
        let managerPublicCap = parentAcct.capabilities.storage.issue<&HybridCustody.Manager{HybridCustody.ManagerPublic}>(HybridCustody.ManagerStoragePath)
        parentAcct.capabilities.publish(managerPublicCap, at: HybridCustody.ManagerPublicPath)
        // --------------------- End setup of parent account ---------------------

        // Publish account to parent
        let owned = childAcct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned account not found")

        var factory = getAccount(childAccountFactoryAddress).capabilities.get<&CapabilityFactory.Manager{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath)
        if factory == nil {
            factory = getAccount(childAccountFactoryAddress).getCapability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath)
        }

        assert(factory!.check(), message: "factory address is not configured properly")

        var filterForChild = getAccount(childAccountFilterAddress).capabilities.get<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        if filterForChild == nil {
            filterForChild = getAccount(childAccountFilterAddress).getCapability<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        }
        assert(filterForChild!.check(), message: "capability filter is not configured properly")

        owned.publishToParent(parentAddress: parentAcct.address, factory: factory!, filter: filterForChild!)

        // claim the account on the parent
        let inboxName = HybridCustody.getChildAccountIdentifier(parentAcct.address)
        let cap = parentAcct.inbox.claim<&HybridCustody.ChildAccount{HybridCustody.AccountPrivate, HybridCustody.AccountPublic, MetadataViews.Resolver}>(inboxName, provider: childAcct.address)
            ?? panic("child account cap not found")

        let manager = parentAcct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager no found")

        manager.addAccount(cap: cap)
    }
}