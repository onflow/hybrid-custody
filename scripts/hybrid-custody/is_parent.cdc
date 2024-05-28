import "HybridCustody"

access(all) fun main(child: Address, parent: Address): Bool {
    let acct = getAuthAccount<auth(Storage) &Account>(child)
    let owned = acct.storage.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
        ?? panic("owned account not found")

    return owned.isChildOf(parent)
}