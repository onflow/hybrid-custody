import "ExampleNFT"

pub fun main(addr: Address): [UInt64] {
    let acct = getAuthAccount(addr)
    let collection = acct.borrow<&ExampleNFT.Collection>(from: ExampleNFT.CollectionStoragePath)
        ?? panic("collection not found")
    return collection.getIDs()
}