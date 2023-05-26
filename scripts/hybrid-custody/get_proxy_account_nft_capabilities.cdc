import "HybridCustody"
import "NonFungibleToken"

// This script iterates through a parent's child accounts, 
// identifies private paths with an accessible NonFungibleToken.Provider, and returns the corresponding typeIds
pub fun main(addr: Address):AnyStruct {
  let account = getAuthAccount(addr)
  let manager = getAuthAccount(addr).borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) ?? panic ("manager does not exist")

  var typeIdsWithProvider = {} as {Address: [String]} 
  
  let providerType = Type<Capability<&{NonFungibleToken.Provider}>>()

  // Iterate through child accounts
  for address in manager.getChildAddresses() {
    let addr = getAuthAccount(address)
    let foundTypes: [String] = []
    let childAcct = manager.borrowAccount(addr: address) ?? panic("child account not found")
    // get all private paths
    addr.forEachPrivate(fun (path: PrivatePath, type: Type): Bool {
      // Check which private paths have NFT Provider AND can be borrowed
      if !type.isSubtype(of: providerType){
        return true
      }
      if let cap = childAcct.getCapability(path: path, type: Type<&{NonFungibleToken.Provider}>()) {
        let providerCap = cap as! Capability<&{NonFungibleToken.Provider}> 

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