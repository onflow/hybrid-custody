import "FungibleToken"

import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"

import "AddressUtils"
import "StringUtils"

/*
RestrictedChildAccount is a contract to help manage child accounts in the scenario
where an application wants to permit their user's to withdraw nfts from their custodial
accounts, but doesn't want to let full ownership of the child account go to the user. There
are many attack vectors that could come from an app giving full custody out to users, including:

    - Replacing stored types to try and trick the app
    - Storing things in an account the app does not want (fungible tokens, for example)
    - Siphoning flow tokens from which the app has to maintain on an account to keep it functioning

This contract is maintained by two main components. The `Manager` resource, and the `RestrictedAccount` resource.
The `Manager` is a wrapper around many `RestrictedAccount`'s and helps add new ones/borrow the ones you already have.
It has helper methods to route NFTs to the right child account, and assistance in borrowing NFTs collections
so you can know what a parent account "owns".

The `RestrictedAccount` is a wrapper around an `AuthAccount` Capability. Accounts shared through the RestrictedAccount
resource will be safe from the following mutating operators with one exception:
    - save
    - link
    - unlink
    - load

That is, you cannot modify the state of the shared account in ways that the app cannot safely handle. The only exception
is that there is a helper method to ensure that collection's are setup to the NFT standard. It will configure public and provider
paths for a collection which is **already stored** in the shared account.
*/
pub contract RestrictedChildAccount {

    pub event ManagerCreated(id: UInt64)
    pub event AccountAdded(parent: Address, child: Address, id: UInt64, name: String, thumbnail: String)
    pub event AccountRemoved(parent: Address, child: Address, id: UInt64, name: String, thumbnail: String)

    pub event SharedAccountPopped(addr: Address, id: UInt64, RestrictedAccountID: UInt64)

    pub let StoragePath: StoragePath
    pub let PublicPath: PublicPath
    pub let SharedAccountStoragePath: StoragePath
    pub let SharedAccountPrivatePath: PrivatePath
    pub let AuthAccountCapabilityPath: PrivatePath

    pub let InboxName: String

    // SharedAccount - A wrapper resource used to store RestrictedAccount resources
    // to publish them. We need to be able to fully redeem the SharedAccount resource,
    // which means we have to be able to store it in a resource we put into a capability.
    pub resource SharedAccount {
        access(self) var acct: @RestrictedAccount?

        // when redeeming from your inbox, you will read a capability to this SharedAccount resource
        // then call pop() to get the actual underlying RestrictedAccount
        pub fun pop(): @RestrictedAccount {
            var tmp: @RestrictedAccount? <- nil
            tmp <-> self.acct

            let acct <- tmp ?? panic("acct is nil")

            emit SharedAccountPopped(addr: self.owner!.address, id: self.uuid, RestrictedAccountID: acct.uuid)
            return <- acct
        }

        init (_ acct: @RestrictedAccount) {
            self.acct <- acct
        }

        destroy () {
            destroy self.acct
        }
    }

    pub resource interface RestrictedAccountPublic {
        pub fun getCollectionPublicCap(path: CapabilityPath): Capability<&{NonFungibleToken.CollectionPublic}>
        pub fun fillFlowVault(v: @FungibleToken.Vault)
        pub fun check(): Bool
        pub fun getAccountAddress(): Address
        pub fun getStoredCollectionTypes(): {Type: StoragePath}
    }

    // RestrictedAccount is a wrapper around an AuthAccount capability. With this 
    // kind of hybrid custody, a parent account cannot save, unlink, or load ANY
    // resources on the child account, and can only link accounts according to the nft standard
    // and only to paths which are not already configured. 
    // 
    // This approach will allow apps which want their NFTs to be utlize hybrid custody to 
    // give their users more functionality to let their nfts being used, without having to worry
    // about malicious actors messing with or altering their accounts in such a way that 
    // they would bear too much a burden to make permitting linking feasible or realistic.
    pub resource RestrictedAccount: MetadataViews.Resolver, RestrictedAccountPublic {
        access(self) let acctCap: Capability<&AuthAccount>

        access(contract) var name: String
        access(contract) var thumbnail: AnyStruct{MetadataViews.File}
        access(contract) var description: String

        // TODO: a list of collections which should not be accessible. Ideally we can avoid this, 
        // but dapper wallet has a deny list of collections which marketplaces are not permitted to use unless
        // they are given permission. As such, we may need to add this functionality for Dapper wallet to
        // adopt this contract/approach, unless they plan to remove that policy altogether which seems unlikely.

        // TODO: a mechanism to share additional capabiltities from the child to the parent
        // in case there are additional pieces of functionality the app is willing to expose
        // this needs to be something entirely owned by the app, the parent account should have
        // no say in how this works

        pub fun getCollectionPublicCap(path: CapabilityPath): Capability<&{NonFungibleToken.CollectionPublic}> {
            return self.getAcct().getCapability<&{NonFungibleToken.CollectionPublic}>(path)
        }

        pub fun getCollectionProviderCap(path: PrivatePath): Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}> {
            return self.getAcct().getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(path)
        }

        // fillFlowVault
        //
        // A one-way method to let anyone give flow tokens to this vault for storage. This might not be allowed,
        // we will need to consult with apps about this piece.
        pub fun fillFlowVault(v: @FungibleToken.Vault) {
            self.getAcct().borrow<&{FungibleToken.Receiver}>(from: /storage/flowTokenVault)!.deposit(from: <-v)
        }

        // deleates to the actual auth account capability to see if it is still valid.
        pub fun check(): Bool {
            return self.acctCap.check()
        }

        // returns the address of the auth account capability
        pub fun getAccountAddress(): Address {
            return self.getAcct().address
        }

        // returns all NFT collection types stored in the configured auth account
        // and returns the storage path they are stored in.
        //
        // NOTE: This doesn't handle cases where the same type is stored in multiple place
        // which is technically valid but not common
        pub fun getStoredCollectionTypes(): {Type: StoragePath} {
            let storedTypes: {Type: StoragePath} = {}
            let acct = self.getAcct()
            acct.forEachStored(fun (path: StoragePath, type: Type): Bool {
                if type.isSubtype(of: Type<@NonFungibleToken.Collection>()) {
                    storedTypes[type] = path
                }
                return true
            })

            return storedTypes
        }

        // reads an NFT collection from the given storage path, and sets it up according to the
        // NFTCollectionData metadata view. If there is nothing in the given path, or if the resource stored is
        // NOT an NFT, this will fail.
        //
        // NOTE: We cannot fully configure collection types here. All we can do is setup NFT-standard interface types.
        pub fun setupStoredCollection(storagePath: StoragePath) {
            let acct = self.getAcct()
            let collection = acct.borrow<&NonFungibleToken.Collection>(from: storagePath)
                ?? panic("no nft collection found in provided storage path")

            // there is a collection here, now we need to borrow its view resolver on the contract
            // to learn how to set it up. We have to do this because there might not be an nft to borrow
            // and resolve this view from. To keep rules consistent, we will use the contract, instead.
            //
            // TODO: we might need a new metadata view for if/when we allow multiple collections to be defined in the same contract
            let segments = StringUtils.split(collection.getType().identifier, ".")
            let addr = AddressUtils.parseAddress(segments[1]) ?? panic("invalid collection type")
            let name = segments[2]

            let borrowedContract = getAccount(addr).contracts.borrow<&ViewResolver>(name: name) ?? panic("contract ViewResolver could not be borrowed")
            let view = borrowedContract.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

            // we will not unlink anything, only link paths which should exist.
            // if they do not, the link will be added. If they do, we will not make any alterations,
            // even the collection is improperly configured.
            acct.link<&{NonFungibleToken.CollectionPublic}>(view.publicPath, target: storagePath)
            acct.link<&{NonFungibleToken.CollectionPublic, NonFungibleToken.Provider}>(view.providerPath, target: storagePath)
        }

        // returns the stored auth account, this is neccessary for storage iteration, and for
        // configuring nft collections with their provider and public paths
        access(self) fun getAcct(): &AuthAccount {
            return self.acctCap.borrow() ?? panic("acct capability is invalid")
        }

        // ---------- Begin MetadataViews.Resolver methods ---------- 
        pub fun getViews(): [Type] {
            return []
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: self.thumbnail
                    )
            }

            return nil
        }

        // ---------- End MetadataViews.Resolver methods ----------

        // ---------- Begin helper mutation methods to let a user customize the details of an auth account they're storing
        access(contract) fun setName(name: String) {
            self.name = name
        }

        pub fun setDescription(description: String) {
            self.description = description
        }

        pub fun setThumbnail(thumbail: {MetadataViews.File}) {
            self.thumbnail = thumbail
        }
        
        // ---------- End helper mutation methods

        init(_ acctCap: Capability<&AuthAccount>, _ name: String, _ thumbnail: AnyStruct{MetadataViews.File}, _ description: String) {
            self.acctCap = acctCap
            self.name = name
            self.thumbnail = thumbnail
            self.description = description
        }
    }

    pub resource interface ManagerPublic {
        pub fun borrowAccountPublic(id: UInt64): &RestrictedAccount{RestrictedAccountPublic, MetadataViews.Resolver}?
        pub fun borrowByNamePublic(name: String): &RestrictedAccount{RestrictedAccountPublic, MetadataViews.Resolver}?
        pub fun getIDs(): [UInt64]
        pub fun cleanupInvalidAccount(id: UInt64)
        pub fun getPublicCapForType(type: Type): Capability<&{NonFungibleToken.CollectionPublic}>?
    }

    // Manager - A resource which manages the child accounts given to it
    // it facilitates adding a new account capabilities, and lets us borrow ones that
    // already exist
    pub resource Manager: ManagerPublic {
        access(self) let accounts: @{UInt64: RestrictedAccount}
        pub let namesToID: {String: UInt64}

        // maintain a mapping of type -> child account id so that the manager
        // can handle where an nft should go when an nft is deposited.
        pub let typeToAccountID: {Type: UInt64}
        
        // ------------------------- Begin private methods ------------------------
        // These can only be accessed with a full reference to the Manager resource

        // Adds a new account to the manager. Saving its name so we can easily reference it in
        // various helper methods
        pub fun registerAccount(_ a: @RestrictedAccount) {
            assert(self.namesToID[a.name] == nil, message: "name is already taken")
            self.namesToID[a.name] = a.uuid

            let display = a.resolveView(Type<MetadataViews.Display>())! as! MetadataViews.Display
            emit AccountAdded(parent: self.owner!.address, child: a.getAccountAddress(), id: a.uuid, name: display.name, thumbnail: display.thumbnail.uri())

            destroy <- self.accounts.insert(key: a.uuid, <- a)
        }

        pub fun removeAccount(id: UInt64) {
            let a <- self.accounts.remove(key: id) ?? panic("account was not found")
            self.namesToID.remove(key: a.name)

            self.namesToID.remove(key: a.name)
            let address = a.getAccountAddress()
            let display = a.resolveView(Type<MetadataViews.Display>())! as! MetadataViews.Display

            emit AccountRemoved(parent: self.owner!.address, child: address, id: a.uuid, name: display.name, thumbnail: display.thumbnail.uri())

            destroy a
        }

        pub fun borrowAccount(id: UInt64): &RestrictedAccount? {
            return &self.accounts[id] as &RestrictedAccount?
        }

        pub fun borrowByName(name: String): &RestrictedAccount? {
            let id = self.namesToID[name]
            if id == nil {
                return nil
            }

            return self.borrowAccount(id: id!)
        }
        
        pub fun borrowAccountForType(type: Type): &RestrictedAccount? {
            let id = self.typeToAccountID[type]
            if id == nil {
                return nil
            }

            let acct = self.borrowAccount(id: id!)
            return acct
        }

        pub fun getProviderCapForType(type: Type): Capability<&{NonFungibleToken.CollectionPublic, NonFungibleToken.Provider}>? {
            let acct = self.borrowAccountForType(type: type)
            if acct == nil {
                return nil
            }

            // this will only work for collections which implement the ViewResolver interface.
            let segments = StringUtils.split(type.identifier, ".")
            let addr = AddressUtils.parseAddress(segments[1]) ?? panic("invalid collection type")
            let name = segments[2]

            let borrowedContract = getAccount(addr).contracts.borrow<&ViewResolver>(name: name) ?? panic("contract ViewResolver could not be borrowed")
            let view = borrowedContract.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

            return acct!.getCollectionProviderCap(path: view.providerPath)
        }

        // mapAccountStoredPaths
        // helper method to map a RestrictedAccount's stored collections to the manager so that we know how to route them.
        //
        // NOTE: This could be dangerous. What if someone phishes a users and gets them to route all NFTs to the wrong account?
        // We will need to think about how to handle this.
        pub fun mapAccountStoredPaths(id: UInt64) {
            let acct = self.borrowAccount(id: id) ?? panic("account not found")

            let storedTypes = acct.getStoredCollectionTypes()
            for t in storedTypes.keys {
                if self.typeToAccountID[t] == nil {
                    self.typeToAccountID[t] = id
                }
            }
        }

        // helper method to rename a shared account. This has to be done on the manager so that we can maintain our mapping
        // of name -> id. If we allow the id to be changed on the RestrictedAccount itself, our mapping will be lost.
        pub fun renameAccount(id: UInt64, name: String) {
            pre {
                self.namesToID[name] == nil : "name is already in use"
            }

            let acct = self.borrowAccount(id: id) ?? panic("account does not exist")
            self.namesToID.remove(key: acct.name)

            acct.setName(name: name)
            self.namesToID.insert(key: name, id)
        }

        // ------------------------- End private methods ------------------------

        pub fun borrowAccountPublic(id: UInt64): &RestrictedAccount{RestrictedAccountPublic, MetadataViews.Resolver}? {
            return &self.accounts[id] as &RestrictedAccount{RestrictedAccountPublic, MetadataViews.Resolver}?
        }

        pub fun borrowByNamePublic(name: String): &RestrictedAccount{RestrictedAccountPublic, MetadataViews.Resolver}? {
            let id = self.namesToID[name]
            if id == nil {
                return nil
            }

            return self.borrowAccountPublic(id: id!)
        }

        pub fun getIDs(): [UInt64] {
            return self.accounts.keys
        }

        // cleanupInvalidAccount
        // callable by anyone, if an account is not valid, it can and should be removed
        // to keep the Manager resource clean.
        pub fun cleanupInvalidAccount(id: UInt64) {
            let a <- self.accounts.remove(key: id) ?? panic("account not found")
            assert(!a.check(), message: "auth account is still valid, only the owner of the account can remove it")

            self.namesToID.remove(key: a.name)
            let address = a.getAccountAddress()
            let display = a.resolveView(Type<MetadataViews.Display>())! as! MetadataViews.Display

            emit AccountRemoved(parent: self.owner!.address, child: address, id: a.uuid, name: display.name, thumbnail: display.thumbnail.uri())

            destroy a
        }

        pub fun safeDeposit(nft: @NonFungibleToken.NFT): @NonFungibleToken.NFT? {
            let acct = self.borrowAccountForType(type: nft.getType())
            if acct == nil {
                return <- nft
            }

            let d = nft.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData
            let cap = acct!.getCollectionPublicCap(path: d.publicPath)
            if !cap.check() {
                return <- nft
            }

            cap.borrow()!.deposit(token: <- nft)
            return nil
        }

        pub fun getPublicCapForType(type: Type): Capability<&{NonFungibleToken.CollectionPublic}>? {
            let acct = self.borrowAccountForType(type: type)
            if acct == nil {
                return nil
            }

            // this will only work for collections which implement the ViewResolver interface.
            let segments = StringUtils.split(type.identifier, ".")
            let addr = AddressUtils.parseAddress(segments[1]) ?? panic("invalid collection type")
            let name = segments[2]

            let borrowedContract = getAccount(addr).contracts.borrow<&ViewResolver>(name: name) ?? panic("contract ViewResolver could not be borrowed")
            let view = borrowedContract.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

            return acct!.getCollectionPublicCap(path: view.publicPath)
        }

        init() {
            self.accounts <- {}
            self.namesToID = {}
            self.typeToAccountID = {}
        }

        destroy() {
            destroy self.accounts
        }
    }

    pub fun createManager(): @Manager {
        let m <- create Manager()
        emit ManagerCreated(id: m.uuid)
        return <- m
    }

    pub fun createRestrictedAccount(
        acctCap: Capability<&AuthAccount>,
        name: String,
        thumbnail: AnyStruct{MetadataViews.File},
        description: String
    ): @RestrictedAccount {
        return <- create RestrictedAccount(acctCap, name, thumbnail, description)
    }

    pub fun wrapAccount(_ a: @RestrictedAccount): @SharedAccount {
        let s <- create SharedAccount(<- a)
        return <- s
    }

    init() {
        let identifier = "RestrictedChildAccount".concat(self.account.address.toString())

        self.StoragePath = StoragePath(identifier: identifier)!
        self.PublicPath = PublicPath(identifier: identifier)!
        
        let sharedAccountIdentifier = identifier.concat("SharedAccount")
        self.SharedAccountPrivatePath = PrivatePath(identifier: sharedAccountIdentifier)!
        self.SharedAccountStoragePath = StoragePath(identifier: sharedAccountIdentifier)!


        let authAccountIdentifier = identifier.concat("AuthAccount")
        self.AuthAccountCapabilityPath = PrivatePath(identifier: authAccountIdentifier)!

        self.InboxName = "RestrictedChildAccount"
    }
}
 