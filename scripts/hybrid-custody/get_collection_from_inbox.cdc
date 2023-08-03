import "MetadataViews"
import "HybridCustody"
import "NonFungibleToken"
import "ExampleNFT"

pub fun main(parent: Address, child: Address) {
    let acct = getAuthAccount(parent)
    let inboxIdentifier = HybridCustody.getChildAccountIdentifier(parent)

    let cap = acct.inbox.claim<&HybridCustody.ChildAccount{HybridCustody.AccountPrivate, HybridCustody.AccountPublic, MetadataViews.Resolver}>(inboxIdentifier, provider: child)
            ?? panic("no inbox entry found")

    // Note(by Bohao): Under the current implementation, cap must be added to the manager before collection can be obtained normally.
    //                 In a sense, I think this is more reasonable.
    if acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) == nil {
        let m <- HybridCustody.createManager(filter: nil)
        acct.save(<- m, to: HybridCustody.ManagerStoragePath)

        acct.unlink(HybridCustody.ManagerPublicPath)
        acct.unlink(HybridCustody.ManagerPrivatePath)

        acct.link<&HybridCustody.Manager{HybridCustody.ManagerPrivate, HybridCustody.ManagerPublic}>(HybridCustody.ManagerPrivatePath, target: HybridCustody.ManagerStoragePath)
        acct.link<&HybridCustody.Manager{HybridCustody.ManagerPublic}>(HybridCustody.ManagerPublicPath, target: HybridCustody.ManagerStoragePath)
    }

    let manager = acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
        ?? panic("manager no found")
    manager.addAccount(cap: cap)

    let factoryGetter = cap.borrow()!.borrowFactoryCapabilityGetter()
    factoryGetter.getCapability(path: ExampleNFT.CollectionPublicPath, type: Type<&{NonFungibleToken.CollectionPublic}>())
        ?? panic("capability not found")
}
