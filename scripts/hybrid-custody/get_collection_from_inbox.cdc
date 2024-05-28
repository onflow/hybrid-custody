import "HybridCustody"
import "NonFungibleToken"
import "ExampleNFT"

access(all) fun main(parent: Address, child: Address) {
    let acct = getAuthAccount<auth(Storage, Capabilities, Inbox) &Account>(parent)
    let childAcct: auth(Storage, Capabilities, Inbox) &Account = getAuthAccount<auth(Storage, Capabilities, Inbox) &Account>(child)
    let inboxIdentifier = HybridCustody.getChildAccountIdentifier(parent)

    let cap = acct.inbox.claim<auth(HybridCustody.Child) &{HybridCustody.AccountPrivate}>(inboxIdentifier, provider: child)
        ?? panic("no inbox entry found")

    for c in childAcct.capabilities.storage.getControllers(forPath: ExampleNFT.CollectionStoragePath) {
        if c.borrowType.isSubtype(of: Type<&{NonFungibleToken.CollectionPublic}>()) {
            cap.borrow()!.getCapability(controllerID: c.capabilityID, type: Type<&{NonFungibleToken.CollectionPublic}>())
            return
        }
    }

    panic("this should not be reached")
}