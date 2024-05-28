import "HybridCustody"
import "MetadataViews"

transaction(name: String, description: String, thumbnail: String) {
    prepare(acct: auth(Storage) &Account) {
        let o = acct.storage.borrow<auth(HybridCustody.Owner) &HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("account not found")
        
        let d = MetadataViews.Display(
            name: name,
            description: description,
            thumbnail: MetadataViews.HTTPFile(url: thumbnail)
        )

        o.setDisplay(d)
    }
}
 