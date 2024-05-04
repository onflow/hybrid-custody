import "HybridCustody"
import "NonFungibleToken"
import "MetadataViews"

/* 
 * TEST SCRIPT
 * This script is a replication of that found in hybrid-custody/get_accessible_child_account_nfts.cdc as it's the best as
 * as can be done without accessing the script's return type in the Cadence testing framework
 */

/// Assertion method to ensure passing test
///
access(all) fun assertPassing(result: {Address: {UInt64: MetadataViews.Display}}, expectedAddressToIDs: {Address: [UInt64]}) {
  for address in expectedAddressToIDs.keys {
    let expectedIDs: [UInt64] = expectedAddressToIDs[address]!

    for i, id in expectedAddressToIDs[address]! {
      if result[address]![id] == nil {
        panic("Resulting ID does not match expected ID!")
      }
    }
  }
}

access(all) fun main(addr: Address, expectedAddressToIDs: {Address: [UInt64]}){
  let manager = getAuthAccount<auth(Storage) &Account>(addr).storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
    ?? panic ("manager does not exist")

  var typeIdsWithProvider: {Address: [String]} = {}
  var nftViews: {Address: {UInt64: MetadataViews.Display}} = {}

  let providerType = Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider}>()
  let collectionType: Type = Type<@{NonFungibleToken.CollectionPublic}>()

  for address in manager.getChildAddresses() {
    let acct = getAuthAccount<auth(Storage, Capabilities) &Account>(address)
    let foundTypes: [String] = []
    let views: {UInt64: MetadataViews.Display} = {}
    let childAcct = manager.borrowAccount(addr: address) ?? panic("child account not found")

    for s in acct.storage.storagePaths {
      for c in acct.capabilities.storage.getControllers(forPath: s) {
        if !c.borrowType.isSubtype(of: providerType){
          continue
        }

        if let cap: Capability = childAcct.getCapability(controllerID: c.capabilityID, type: providerType) {
          let providerCap = cap as! Capability<&{NonFungibleToken.Provider}> 

          if !providerCap.check(){
            continue
          }

          foundTypes.append(cap.borrow<&AnyResource>()!.getType().identifier)
          typeIdsWithProvider[address] = foundTypes
          break
        }
      }
    }

    // iterate storage, check if typeIdsWithProvider contains the typeId, if so, add to views
    acct.storage.forEachStored(fun (path: StoragePath, type: Type): Bool {

      if typeIdsWithProvider[address] == nil {
        return true
      }

      for key in typeIdsWithProvider.keys {
        for idx, value in typeIdsWithProvider[key]! {
          let value = typeIdsWithProvider[key]!

          if value[idx] != type.identifier {
            continue
          } else {
            if type.isInstance(collectionType) {
              continue
            }
            if let collection = acct.storage.borrow<&{NonFungibleToken.CollectionPublic}>(from: path) { 
              // Iterate over IDs & resolve the view
              for id in collection.getIDs() {
                let nft = collection.borrowNFT(id)!
                if let display = nft.resolveView(Type<MetadataViews.Display>())! as? MetadataViews.Display {
                  views.insert(key: id, display)
                }
              }
            }
            continue
          }
        }
      }
      return true
    })
    nftViews[address] = views
  }
	// Assert instead of return for testing purposes here

  assertPassing(result: nftViews, expectedAddressToIDs: expectedAddressToIDs)
  // return nftViews
}