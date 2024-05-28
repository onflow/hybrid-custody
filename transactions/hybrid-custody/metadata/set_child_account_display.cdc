import "HybridCustody"
import "MetadataViews"

transaction(childAddress: Address, name: String, description: String, thumbnail: String) {
    prepare(acct: auth(Storage) &Account) {
        let m = acct.storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager not found")
        
        let d = MetadataViews.Display(
            name: name,
            description: description,
            thumbnail: MetadataViews.HTTPFile(url: thumbnail)
        )

        m.setChildAccountDisplay(address: childAddress, d)
    }
}