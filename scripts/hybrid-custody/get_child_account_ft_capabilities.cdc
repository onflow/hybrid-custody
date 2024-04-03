import "HybridCustody"
import "FungibleToken"

// This script iterates through a parent's child accounts, 
// identifies private paths with an accessible FungibleToken.Provider, and returns the corresponding typeIds
access(all) fun main(addr: Address):AnyStruct {
  let account = getAuthAccount<auth(Storage) &Account>(addr)
  let manager = getAuthAccount<auth(Storage) &Account>(addr).storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
    ?? panic ("manager does not exist")

  var typeIdsWithProvider: {Address: [String]} = {}
  
  let providerType = Type<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>()

  // Iterate through child accounts
  for address in manager.getChildAddresses() {
    let addr = getAuthAccount<auth(Storage, Capabilities) &Account>(address)
    let foundTypes: [String] = []
    let childAcct = manager.borrowAccount(addr: address) ?? panic("child account not found")
    // get all private paths

    for s in addr.storage.storagePaths {
      for c in addr.capabilities.storage.getControllers(forPath: s) {
        if !c.borrowType.isSubtype(of: providerType){
          continue
        }

        if let cap = childAcct.getCapability(controllerID: c.capabilityID, type: providerType) {
          let providerCap = cap as! Capability<&{FungibleToken.Provider}> 

          if !providerCap.check(){
            continue
          }

          foundTypes.append(cap.borrow<&AnyResource>()!.getType().identifier)
          typeIdsWithProvider[address] = foundTypes
          break
        }
      }
    }      
  }

  return typeIdsWithProvider
}
 