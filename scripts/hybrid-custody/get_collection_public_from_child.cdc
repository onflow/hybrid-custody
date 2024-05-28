import "HybridCustody"
import "NonFungibleToken"

access(all) fun main(parent: Address, child: Address, path: PublicPath, type: Type): [UInt64] {
    let parentAcct = getAuthAccount<auth(Storage) &Account>(parent)
    let manager = parentAcct.storage.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
        ?? panic("manager not found")
    let child = manager.borrowAccountPublic(addr: child) ?? panic("child account not found")
    let cap = child.getPublicCapability(path: path, type: type)
        ?? panic("could not get capability")
    let collection = cap.borrow<&{NonFungibleToken.CollectionPublic}>()
        ?? panic("failed to borrow collection")
    return collection.getIDs()
}