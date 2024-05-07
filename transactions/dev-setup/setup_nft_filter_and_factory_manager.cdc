import "CapabilityFilter"
import "CapabilityFactory"
import "NFTCollectionPublicFactory"
import "NFTProviderAndCollectionFactory"
import "NFTProviderFactory"
import "FTProviderFactory"

import "NonFungibleToken"
import "FungibleToken"

/* --- Helper Methods --- */
//
/// Returns a type identifier for an NFT Collection
///
access(all) fun deriveCollectionTypeIdentifier(_ contractAddress: Address, _ contractName: String): String {
    return "A.".concat(withoutPrefix(contractAddress.toString())).concat(".").concat(contractName).concat(".Collection")
}

/// Taken from AddressUtils private method
///
access(all) fun withoutPrefix(_ input: String): String{
    var address=input

    //get rid of 0x
    if address.length>1 && address.utf8[1] == 120 {
        address = address.slice(from: 2, upTo: address.length)
    }

    //ensure even length
    if address.length%2==1{
        address="0".concat(address)
    }
    return address
}

/* --- Transaction Block --- */
//
/// This transaction can be used by most developers implementing HybridCustody as the single pre-requisite transaction
/// to setup filter functionality between linked parent and child accounts.
///
/// Creates a CapabilityFactory Manager and CapabilityFilter.AllowlistFilter in the signing account (if needed), adding
/// NFTCollectionPublicFactory, NFTProviderAndCollectionFactory, & NFTProviderFactory to the CapabilityFactory Manager
/// and the Collection Type to the CapabilityFilter.AllowlistFilter
///
/// For more info, see docs at https://developers.onflow.org/docs/hybrid-custody/
////
transaction(nftContractAddress: Address, nftContractName: String) {
    prepare(acct: auth(Storage, Capabilities) &Account) {

        /* --- CapabilityFactory Manager configuration --- */
        //
        if acct.storage.borrow<&AnyResource>(from: CapabilityFactory.StoragePath) == nil {
            let f <- CapabilityFactory.createFactoryManager()
            acct.storage.save(<-f, to: CapabilityFactory.StoragePath)
        }

        if !acct.capabilities.get<&{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath).check() {
            acct.capabilities.unpublish(CapabilityFactory.PublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&{CapabilityFactory.Getter}>(CapabilityFactory.StoragePath),
                at: CapabilityFactory.PublicPath
            )
        }

        assert(
            acct.capabilities.get<&{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath).check() == true,
            message: "CapabilityFactory is not setup properly"
        )

        let factoryManager = acct.storage.borrow<auth(CapabilityFactory.Add) &CapabilityFactory.Manager>(from: CapabilityFactory.StoragePath)
            ?? panic("CapabilityFactory Manager not found")

        // Add NFT-related Factories to the Manager
        factoryManager.updateFactory(Type<&{NonFungibleToken.CollectionPublic}>(), NFTCollectionPublicFactory.Factory())
        factoryManager.updateFactory(Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(), NFTProviderAndCollectionFactory.Factory())
        factoryManager.updateFactory(Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider}>(), NFTProviderFactory.Factory())

        /* --- AllowlistFilter configuration --- */
        //
        if acct.storage.borrow<&AnyResource>(from: CapabilityFilter.StoragePath) == nil {
            acct.storage.save(<-CapabilityFilter.createFilter(Type<@CapabilityFilter.AllowlistFilter>()), to: CapabilityFilter.StoragePath)
        }

        if !acct.capabilities.get<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath).check(){
            acct.capabilities.unpublish(CapabilityFilter.PublicPath)

            acct.capabilities.publish(
                acct.capabilities.storage.issue<&{CapabilityFilter.Filter}>(CapabilityFilter.StoragePath),
                at: CapabilityFilter.PublicPath
            )
        }

        assert(
            acct.capabilities.get<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath).check(),
            message: "AllowlistFilter is not setup properly"
        )

        let filter = acct.storage.borrow<auth(CapabilityFilter.Add) &CapabilityFilter.AllowlistFilter>(from: CapabilityFilter.StoragePath)
            ?? panic("AllowlistFilter does not exist")

        // Construct an NFT Collection Type from the provided args & add to the AllowlistFilter
        let c = CompositeType(deriveCollectionTypeIdentifier(nftContractAddress, nftContractName))
            ?? panic("Problem constructing CompositeType from given NFT contract address and name")
        filter.addType(c)
    }
}
