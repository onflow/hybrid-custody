import "ExampleNFT2"

access(all) fun main(addr: Address): [UInt64] {
    let acct = getAuthAccount<auth(Storage) &Account>(addr)
    let collection = acct.storage.borrow<&ExampleNFT2.Collection>(from: ExampleNFT2.CollectionStoragePath)
        ?? panic("collection not found")
    return collection.getIDs()
}