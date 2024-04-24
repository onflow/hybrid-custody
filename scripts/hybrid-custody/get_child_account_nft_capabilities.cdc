import "HybridCustody"
import "NonFungibleToken"

// This script iterates through a parent's child accounts, 
// identifies private paths with an accessible NonFungibleToken.Provider, and returns the corresponding typeIds
access(all) fun main(addr: Address): AnyStruct {
  let account = getAuthAccount<auth(Storage) &Account>(addr)
  let manager = getAuthAccount<auth(Storage) &Account>(addr).storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) ?? panic ("manager does not exist")

  var typeIdsWithProvider: {Address: [String]} = {}
  
  let providerType = Type<auth(NonFungibleToken.Withdraw, NonFungibleToken.Owner) &{NonFungibleToken.Provider}>()

  // Iterate through child accounts
  for address in manager.getChildAddresses() {
    let addr = getAuthAccount<auth(Storage, Capabilities) &Account>(address)
    let foundTypes: [String] = []
    let childAcct = manager.borrowAccount(addr: address) ?? panic("child account not found")
    // get all private paths

    for s in addr.storage.storagePaths {
      let controllers = addr.capabilities.storage.getControllers(forPath: s)
      for c in controllers {
        if !c.borrowType.isSubtype(of: providerType) {
          continue
        }

        if let cap = childAcct.getCapability(controllerID: c.capabilityID, type: providerType) {
          let providerCap = cap as! Capability<auth(NonFungibleToken.Withdraw, NonFungibleToken.Owner) &{NonFungibleToken.Provider}> 

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