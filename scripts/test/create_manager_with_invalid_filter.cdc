import "CapabilityFilter"
import "HybridCustody"

access(all) fun main(address: Address): Bool {
    let acct = getAuthAccount<auth(Capabilities, Storage) &Account>(address)
    // Retrieving invalid Filter capability
    let invalidFilterCap = acct.capabilities.storage.issue<&{CapabilityFilter.Filter}>(CapabilityFilter.StoragePath)

    acct.capabilities.storage.getController(byCapabilityID: invalidFilterCap.id)!.delete()

    // This step should fail due to CapabilityFilter.Filter Capability check on Manager init
    let manager <- HybridCustody.createManager(filter: invalidFilterCap)
    // Destroy and return
    destroy manager
    return false
}