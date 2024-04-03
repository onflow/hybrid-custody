import "HybridCustody"

import "FungibleToken"
import "ExampleToken"
import "FungibleTokenMetadataViews"

// Verify that a child address borrowed as a child will let the parent borrow an FT provider capability
access(all) fun main(parent: Address, child: Address) {
    let acct = getAuthAccount<auth(BorrowValue) &Account>(parent)
    let m = acct.storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
        ?? panic("manager does not exist")

    let childAcct = m.borrowAccount(addr: child) ?? panic("child account not found")

    let vaultData = ExampleToken.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
        ?? panic("Could not get the vault data view for ExampleToken")

    // find the et provider
    var controllerID: UInt64? = nil
    let desiredType = Type<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>()
    let childAuthAcct = getAuthAccount<auth(Capabilities) &Account>(child)
    for c in childAuthAcct.capabilities.storage.getControllers(forPath: vaultData.storagePath) {
        if c.borrowType.isSubtype(of: desiredType) {
            controllerID = c.capabilityID
            break
        }
    }

    assert(controllerID != nil, message: "could not find controller id for FungibleToken Provider")


    let nakedCap = childAcct.getCapability(controllerID: controllerID!, type: Type<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>())
        ?? panic("Could not borrow reference to the owner's Vault!")
    let providerCap = nakedCap as! Capability<&{FungibleToken.Provider}>
    assert(providerCap.check(), message: "invalid provider capability")
    providerCap.borrow()!
}