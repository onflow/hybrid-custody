import "MetadataViews"

pub contract HybridCustodyMetadata {
    // Initial version taken from the Niftory MetadataViewsManager:
    // https://github.com/Niftory/niftory-flow/blob/main/cadence/contracts/MetadataViewsManager.cdc
    // This resolver is what will be used to resolve metadata views
    pub struct interface Resolver {
        // The type of the particular MetadataViews struct this Resolver creates
        pub let type: Type

        // The actual resolve function
        pub fun resolve(_ nftRef: &AnyResource): AnyStruct?
    }

    pub struct ProxyAccountDisplayResolver: Resolver {
        pub let type: Type

        pub fun resolve(_ nftRef: &AnyResource): AnyStruct? {
            
            return nil
        }

        init(_ t: Type) {
            self.type = t
        }
    }
}