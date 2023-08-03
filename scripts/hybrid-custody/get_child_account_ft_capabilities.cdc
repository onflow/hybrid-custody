import "HybridCustody"
import "FungibleToken"

// This script iterates through a parent's child accounts,
// identifies private paths with an accessible FungibleToken.Provider, and returns the corresponding typeIds
pub fun main(addr: Address):AnyStruct {
  let account = getAuthAccount(addr)
  let manager = getAuthAccount(addr).borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) ?? panic ("manager does not exist")

  var typeIdsWithProvider = {} as {Address: [String]}

  let providerType = Type<Capability<&{FungibleToken.Provider}>>()

  // Iterate through child accounts
  for address in manager.getChildAddresses() {
    let addr = getAuthAccount(address)
    let foundTypes: [String] = []
    let childAcct = manager.borrowAccount(addr: address) ?? panic("child account not found")
    let factoryGetter = childAcct.borrowFactoryCapabilityGetter()
    // get all private paths
    addr.forEachPrivate(fun (path: PrivatePath, type: Type): Bool {
			// Check which private paths have FT Provider AND can be borrowed
      if !type.isSubtype(of: providerType){
        return true
      }
      if let cap = factoryGetter.getCapability(path: path, type: Type<&{FungibleToken.Provider}>()) {
        let providerCap = cap as! Capability<&{FungibleToken.Provider}>

        if !providerCap.check(){
          return true
        }

          foundTypes.append(cap.borrow<&AnyResource>()!.getType().identifier)
        }
        return true
      })

      typeIdsWithProvider[address] = foundTypes
  }

  return typeIdsWithProvider
}
