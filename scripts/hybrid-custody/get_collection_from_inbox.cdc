import "HybridCustody"
import "NonFungibleToken"
import "ExampleNFT"

pub fun main(parent: Address, child: Address) {
    let acct = getAuthAccount(parent)
    let inboxIdentifier = HybridCustody.getChildAccountIdentifier(parent)

    let cap = acct.inbox.claim<&HybridCustody.ChildAccount{HybridCustody.AccountPrivate}>(inboxIdentifier, provider: child)
        ?? panic("no inbox entry found")

    cap.borrow()!.getCapability(path: ExampleNFT.CollectionPublicPath, type: Type<&{NonFungibleToken.CollectionPublic}>())
        ?? panic("capability not found")
}