/* 
*
*  This is an example implementation of a Flow Non-Fungible Token
*  It is not part of the official standard but it assumed to be
*  similar to how many NFTs would implement the core functionality.
*
*  This contract does not implement any sophisticated classification
*  system for its NFTs. It defines a simple NFT with minimal metadata.
*   
*/

import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"
import "FungibleToken"

access(all) contract ExampleNFT2: ViewResolver {

    access(all) var totalSupply: UInt64

    access(all) event ContractInitialized()
    access(all) event Withdraw(id: UInt64, from: Address?)
    access(all) event Deposit(id: UInt64, to: Address?)

    access(all) event CollectionCreated(id: UInt64)
    access(all) event CollectionDestroyed(id: UInt64)

    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath
    access(all) let MinterPublicPath: PublicPath

    access(all) resource NFT: NonFungibleToken.NFT, ViewResolver.Resolver {
        access(all) let id: UInt64

        access(all) let name: String
        access(all) let description: String
        access(all) let thumbnail: String
        access(self) let royalties: [MetadataViews.Royalty]

        init(
            id: UInt64,
            name: String,
            description: String,
            thumbnail: String,
            royalties: [MetadataViews.Royalty]
        ) {
            self.id = id
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.royalties = royalties
        }
    
        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>()
            ]
        }

        access(all) view fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.thumbnail
                        )
                    )
                case Type<MetadataViews.Editions>():
                    // There is no max number of NFTs that can be minted from this contract
                    // so the max edition field value is set to nil
                    let editionInfo = MetadataViews.Edition(name: "Example NFT Edition", number: self.id, max: nil)
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(
                        editionList
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        self.royalties
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://example-nft.onflow.org/".concat(self.id.toString()))
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: ExampleNFT2.CollectionStoragePath,
                        publicPath: ExampleNFT2.CollectionPublicPath,
                        publicCollection: Type<&ExampleNFT2.Collection>(),
                        publicLinkedType: Type<&ExampleNFT2.Collection>(),
                        createEmptyCollectionFunction: (fun (): @{NonFungibleToken.Collection} {
                            return <-ExampleNFT2.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                        ),
                        mediaType: "image/svg+xml"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "The Example Collection",
                        description: "This collection is used as an example to help you develop your next Flow NFT.",
                        externalURL: MetadataViews.ExternalURL("https://example-nft.onflow.org"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/flow_blockchain")
                        }
                    )
            }
            return nil
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- ExampleNFT2.createEmptyCollection()
        }
    }

    access(all) resource interface ExampleNFT2CollectionPublic: NonFungibleToken.Collection {
        access(all) fun deposit(token: @{NonFungibleToken.NFT})
        access(all) fun borrowExampleNFT2(id: UInt64): &ExampleNFT2.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow ExampleNFT2 reference: the ID of the returned reference is incorrect"
            }
        }
    }

    access(all) resource Collection: ExampleNFT2CollectionPublic {
        access(all) event ResourceDestroyed(id: UInt64 = self.uuid)

        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        init () {
            self.ownedNFTs <- {}
            emit CollectionCreated(id: self.uuid)
        }

        access(all) view fun getLength(): Int {
            return self.ownedNFTs.length
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        access(NonFungibleToken.Withdraw | NonFungibleToken.Owner) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let token <- token as! @ExampleNFT2.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs returns an array of the IDs that are in the collection
        access(all) view fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)!
        }
 
        access(all) fun borrowExampleNFT2(id: UInt64): &ExampleNFT2.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as &{NonFungibleToken.NFT}?)!
                return ref as! &ExampleNFT2.NFT
            }

            return nil
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- create Collection()
        }

        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            return {
                Type<@ExampleNFT2.NFT>(): true
            }
        }

        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@ExampleNFT2.NFT>()
        }
    }

    // public function that anyone can call to create a new empty collection
    access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
        return <- create Collection()
    }

    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    access(all) resource NFTMinter {

        // mintNFT mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        access(all) fun mintNFT(
            recipient: &{NonFungibleToken.CollectionPublic},
            name: String,
            description: String,
            thumbnail: String,
            royaltyReceipient: Address,
        ) {
            ExampleNFT2.totalSupply = ExampleNFT2.totalSupply + 1
            self.mintNFTWithId(recipient: recipient, name: name, description: description, thumbnail: thumbnail, royaltyReceipient: royaltyReceipient, id: ExampleNFT2.totalSupply)
        }

        access(all) fun mintNFTWithId(
            recipient: &{NonFungibleToken.CollectionPublic},
            name: String,
            description: String,
            thumbnail: String,
            royaltyReceipient: Address,
            id: UInt64
        ) {
            let royaltyRecipient = getAccount(royaltyReceipient).capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)!
            let cutInfo = MetadataViews.Royalty(receiver: royaltyRecipient, cut: 0.05, description: "")
            // create a new NFT
            var newNFT <- create NFT(
                id: id,
                name: name,
                description: description,
                thumbnail: thumbnail,
                royalties: [cutInfo]
            )

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)
        }

        // mintNFT mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        access(all) fun mintNFTWithRoyaltyCuts(
            recipient: &{NonFungibleToken.CollectionPublic},
            name: String,
            description: String,
            thumbnail: String,
            royaltyReceipients: [Address],
            royaltyCuts: [UFix64]
        ) {
            assert(royaltyReceipients.length == royaltyCuts.length, message: "mismatched royalty recipients and cuts")
            let royalties: [MetadataViews.Royalty] = []

            var index = 0
            while index < royaltyReceipients.length {
                let royaltyRecipient = getAccount(royaltyReceipients[index]).capabilities.get<&{FungibleToken.Receiver}>(/public/placeholder)!
                let cutInfo = MetadataViews.Royalty(receiver: royaltyRecipient, cut: royaltyCuts[index], description: "")
                royalties.append(cutInfo)
                index = index + 1
            }            

            ExampleNFT2.totalSupply = ExampleNFT2.totalSupply + 1

            // create a new NFT
            var newNFT <- create NFT(
                id: ExampleNFT2.totalSupply,
                name: name,
                description: description,
                thumbnail: thumbnail,
                royalties: royalties
            )

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)
        }
    }

    /// Function that resolves a metadata view for this contract.
    ///
    /// @param view: The Type of the desired view.
    /// @return A structure representing the requested view.
    ///
    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<MetadataViews.NFTCollectionData>():
                return MetadataViews.NFTCollectionData(
                        storagePath: ExampleNFT2.CollectionStoragePath,
                        publicPath: ExampleNFT2.CollectionPublicPath,
                        publicCollection: Type<&ExampleNFT2.Collection>(),
                        publicLinkedType: Type<&ExampleNFT2.Collection>(),
                        createEmptyCollectionFunction: (fun (): @{NonFungibleToken.Collection} {
                            return <-ExampleNFT2.createEmptyCollection()
                        })
                )
            case Type<MetadataViews.NFTCollectionDisplay>():
                let media = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                    ),
                    mediaType: "image/svg+xml"
                )
                return MetadataViews.NFTCollectionDisplay(
                    name: "The Example Collection",
                    description: "This collection is used as an example to help you develop your next Flow NFT.",
                    externalURL: MetadataViews.ExternalURL("https://example-nft.onflow.org"),
                    squareImage: media,
                    bannerImage: media,
                    socials: {
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/flow_blockchain")
                    }
                )
        }
        return nil
    }

    /// Function that returns all the Metadata Views implemented by a Non Fungible Token
    ///
    /// @return An array of Types defining the implemented views. This value will be used by
    ///         developers to know which parameter to pass to the resolveView() method.
    ///
    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.NFTCollectionDisplay>()
        ]
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0

        // Set the named paths
        self.CollectionStoragePath = /storage/exampleNFT2Collection
        self.CollectionPublicPath = /public/exampleNFT2Collection
        self.MinterStoragePath = /storage/exampleNFT2Minter
        self.MinterPublicPath = /public/exampleNFT2Minter

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.storage.save(<-collection, to: self.CollectionStoragePath)
        let cap = self.account.capabilities.storage.issue<&ExampleNFT2.Collection>(self.CollectionStoragePath)
        self.account.capabilities.publish(cap, at: self.CollectionPublicPath)


        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)

        let minterCap = self.account.capabilities.storage.issue<&ExampleNFT2.NFTMinter>(self.MinterStoragePath)

        emit ContractInitialized()
    }
}
 