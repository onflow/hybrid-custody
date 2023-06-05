import "ExampleNFT2"

pub fun main(addr: Address): [UInt64] {
    let acct = getAuthAccount(addr)
    let collection = acct.borrow<&ExampleNFT2.Collection>(from: ExampleNFT2.CollectionStoragePath)
        ?? panic("collection not found")
    return collection.getIDs()
}