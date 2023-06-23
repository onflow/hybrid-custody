import "HybridCustody"
import "MetadataViews"

transaction(childAddress: Address, name: String, description: String, thumbnail: String) {
    prepare(acct: AuthAccount) {
        let m = acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager not found")
        
        let d = MetadataViews.Display(
            name: name,
            description: description,
            thumbnail: MetadataViews.HTTPFile(url: thumbnail)
        )

        m.setChildDisplay(child: childAddress, display: d)
    }
}