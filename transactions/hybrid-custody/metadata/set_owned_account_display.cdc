import "HybridCustody"
import "MetadataViews"

transaction(name: String, description: String, thumbnail: String) {
    prepare(acct: AuthAccount) {
        let o = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("account not found")
        
        let d = MetadataViews.Display(
            name: name,
            description: description,
            thumbnail: MetadataViews.HTTPFile(url: thumbnail)
        )

        o.setDisplay(d)
    }
}
 