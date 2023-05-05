import "HybridCustody"
import "MetadataViews"

transaction(name: String, description: String, thumbnail: String) {
    prepare(acct: AuthAccount) {
        let a = acct.borrow<&HybridCustody.ChildAccount>(from: HybridCustody.ChildStoragePath)
            ?? panic("account not found")
        
        let d = MetadataViews.Display(
            name: name,
            description: description,
            thumbnail: MetadataViews.HTTPFile(url: thumbnail)
        )

        a.setDisplay(d)
    }
}
 