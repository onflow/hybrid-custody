import "CapabilityFilter"
import "HybridCustody"

pub fun main(address: Address): Bool {
    // Retrieving invalid Filter capability
    let invalidFilterCap = getAuthAccount(address).getCapability<&{CapabilityFilter.Filter}>(CapabilityFilter.PrivatePath)
    // This step should fail due to CapabilityFilter.Filter Capability check on Manager init
    let manager <- HybridCustody.createManager(filter: invalidFilterCap)
    // Destroy and return
    destroy manager
    return false
}