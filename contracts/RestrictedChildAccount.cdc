import "MetadataViews"

import "LinkedAccount"
import "CapabilityProxy"
import "CapabilityFilter"
import "CapabilityFactory"

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
        pub fun getPublicCap(path: PublicPath, type: Type): Capability?
        pub fun getPrivateCap(path: PrivatePath, type: Type): Capability?
        pub fun getCapability(path: CapabilityPath, type: Type): Capability?
        pub fun check(): Bool
        pub fun getAccountAddress(): Address
        pub fun getStoredTypes(_ t: Type): {Type: StoragePath}
        pub fun borrowProxyPublicCap(type: Type): Capability?
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
    pub resource RestrictedAccount: MetadataViews.Resolver, RestrictedAccountPublic, LinkedAccount.Account {
        access(self) let acctCap: Capability<&AuthAccount>
        access(self) let proxy: Capability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPrivate, CapabilityProxy.GetterPublic}>
        access(contract) let filter: Capability<&{CapabilityFilter.Filter}>?
        access(contract) let factoryManager: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>

        access(contract) var name: String
        access(contract) var thumbnail: AnyStruct{MetadataViews.File}
        access(contract) var description: String

        pub fun getPublicCap(path: PublicPath, type: Type): Capability? {
            return self.getCapability(path: path, type: type)
        }

        pub fun getPrivateCap(path: PrivatePath, type: Type): Capability? {
            return self.getCapability(path: path, type: type)
        }

        pub fun getCapability(path: CapabilityPath, type: Type): Capability? {
            if !self.factoryManager.check() {
                return nil
            }

            let factory = self.factoryManager.borrow()!.getFactory(type)
            if factory == nil {
                return nil
            }

            let fm = factory!.getCapability(acct: self.getAcct(), path: path)
            return fm
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
        pub fun getStoredTypes(_ t: Type): {Type: StoragePath} {
            let storedTypes: {Type: StoragePath} = {}
            let acct = self.getAcct()
            acct.forEachStored(fun (path: StoragePath, type: Type): Bool {
                if type.isSubtype(of: t) {
                    storedTypes[type] = path
                }
                return true
            })

            return storedTypes
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

        pub fun borrowProxyPublicCap(type: Type): Capability? {
            if !self.proxy.check() {
                return nil
            }

            return self.proxy.borrow()!.getPublicCapability(type)
        }

        pub fun borrowProxy(): &CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}? {
            if !self.proxy.check() {
                return nil
            }

            return self.proxy.borrow()
        }

        init(
            _ acctCap: Capability<&AuthAccount>, 
            _ name: String, 
            _ thumbnail: AnyStruct{MetadataViews.File}, 
            _ description: String, 
            _ proxy: Capability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPrivate, CapabilityProxy.GetterPublic}>,
            _ filter: Capability<&{CapabilityFilter.Filter}>?,
            _ factoryManager: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>
        ) {
            self.acctCap = acctCap
            self.name = name
            self.thumbnail = thumbnail
            self.description = description
            self.proxy = proxy
            self.filter = filter
            self.factoryManager = factoryManager
        }
    }

    pub resource interface ManagerPublic {
        pub fun borrowAccountPublic(id: UInt64): &RestrictedAccount{RestrictedAccountPublic, MetadataViews.Resolver}?
        pub fun borrowByNamePublic(name: String): &RestrictedAccount{RestrictedAccountPublic, MetadataViews.Resolver}?
        pub fun getIDs(): [UInt64]
        pub fun cleanupInvalidAccount(id: UInt64)
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
        description: String,
        proxy: Capability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPrivate, CapabilityProxy.GetterPublic}>,
        filter: Capability<&{CapabilityFilter.Filter}>?,
        factoryManager: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>
    ): @RestrictedAccount {
        pre {
            acctCap.check(): "invalid auth account capability"
            proxy.check(): "invalid proxy capability"
            filter == nil || filter!.check(): "capability filter must be nil or valid"
        }

        assert(acctCap.borrow()!.address == proxy.borrow()!.owner!.address, message: "proxy and auth account cap must be owned by the same address")
        return <- create RestrictedAccount(acctCap, name, thumbnail, description, proxy, filter, factoryManager)
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
 