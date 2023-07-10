import "HybridCustody"
import "MetadataViews"

// This transaction demonstrates how you can share ownership of one account with another, giving the receiving
// account administrative access to the account being shared without revoking keys or removing access from the originating account.
// This is especailly useful if you want to manage accounts from one central place, but still want to be able to do things
// like sign in 
transaction(shareWith: Address) {
    prepare(acct: AuthAccount) {
        let ownedAccount = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.ChildStoragePath)
            ?? panic("no owned account found")

        let identifier = HybridCustody.getOwnerIdentifier(shareWith)
        let path = PrivatePath(identifier: identifier)!

        acct.link<&{HybridCustody.OwnedAccountPrivate, HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>(path, target: HybridCustody.ChildStoragePath)
        let cap = acct.getCapability<&{HybridCustody.OwnedAccountPrivate, HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>(path)
        assert(cap.check(), message: "owned account capability check failed")

        acct.inbox.publish(cap, name: identifier, recipient: shareWith)
    }
}