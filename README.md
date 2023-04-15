# RestrictedChildAccount

This repo contains a primary contract for managing restricted AuthAccounts to permit
hybrid custody in scenarios where apps only want to share a subset of resources on their
accounts with a user's main wallet (the parent account)

Apps need assurances that their own resources are safe from malicious actors, so giving out full
custody might not be the form of hybrid custody that they want. In this model, the app still
maintains control of their managed accounts, but they can:

1. Share nft collections freely, with a built-in `CapabilityFilter` to prevent certain collections from being exposed
1. Share additional capabilities (public or private) with a parent account via a `CapabilityProxy` resource

## RestrictedAccount

This is our primary resource. The main components that control the account are as follows:
```cadence
pub resource RestrictedAccount: MetadataViews.Resolver, RestrictedAccountPublic {
        access(self) let acctCap: Capability<&AuthAccount>
        access(self) let proxy: Capability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPrivate, CapabilityProxy.GetterPublic}>
        access(contract) let filter: Capability<&{CapabilityFilter.Filter}>?
        ...

```

- **acctCap** - The shared auth account capability.
- **proxy** - A resource which allows the child account to share any capability up to the parent.
    This is added so that we don't have to take a view on what resources are "valid" to be shared. The proxy maintains a list of public and private capabilities. The public capabilities will be viewable by anyone. The private capabilities will only be obtainable with a reference to its `RestrictedChildAccount` resource
- **filter** - A resource that is called before we yield NFT provider capabilities to a parent 
    account. This is needed because some products like DapperWallet don't permit withdraws of all
    NFT types. Some can be withdrawn, some cannot, and some are only usable on certain marketplaces.
    The filter is owned by the each app sharing an account and is given to us via a capability. Apps 
    can define their own filters, or they can use one of the three built-in for their convenience:

    1. AllowAllFilter - Permits everything, this is a passthrough implementation
    1. DenylistFilter - Permits everything **not** in a list maintained in the filter
    1. Allowlistfilter - Only permits types present in a list maintained in the filter


It also contains some information to resolve the `Display` Metadataview.

```cadence
        access(contract) var name: String
        access(contract) var thumbnail: AnyStruct{MetadataViews.File}
        access(contract) var description: String
```

This resource is centered around NFT Collections which are by far (currently) the most common type of 
resource which hybrid custody unlocks functionality for. For marketplaces and other platforms build on
NFT standards, this should give them access to the resource types they need.

To manager each child account shared with a parent is the `Manager` resource. It will facilitate 
keeping track of and accessing `RestrictChildAccount` resources. The manager also has some methods to
help route nfts to their original child accounts, can help find child accounts with the provider of an
nft type being looked for

## Example Transactions

### Publish RestrictedAccount to parent address
```cadence
#allowAccountLinking

import "RestrictedChildAccount"
import "CapabilityProxy"
import "CapabilityFilter"
import "CapabilityFactory"

import "MetadataViews"

transaction(parent: Address, name: String, description: String, thumbnail: String, factoryAddress: Address) {
    let authAccountCap: Capability<&AuthAccount>

    prepare(acct: AuthAccount) {
        // Get the AuthAccount Capability, linking if necessary
        if !acct.getCapability<&AuthAccount>(RestrictedChildAccount.AuthAccountCapabilityPath).check() {
            self.authAccountCap = acct.linkAccount(RestrictedChildAccount.AuthAccountCapabilityPath)!
        } else {
            self.authAccountCap = acct.getCapability<&AuthAccount>(RestrictedChildAccount.AuthAccountCapabilityPath)
        }

        // ------------ BEGIN Setup CapabilityProxy
        if acct.borrow<&CapabilityProxy>(from: CapabilityProxy.StoragePath) == nil {
            let proxy <- CapabilityProxy.createProxy()
            acct.save(<-proxy, to: CapabilityProxy.StoragePath)
        }

        if !acct.getCapability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>(CapabilityProxy.PrivatePath).check() {
            acct.unlink(CapabilityProxy.PrivatePath)
            acct.link<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>(CapabilityProxy.PrivatePath, target: CapabilityProxy.StoragePath)
        }

        let proxy = acct.getCapability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>(CapabilityProxy.PrivatePath)
        assert(proxy.check(), message: "failed to configure capability proxy")

        acct.link<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic}>(CapabilityProxy.PublicPath, target: CapabilityProxy.StoragePath)
        acct.link<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>(CapabilityProxy.PrivatePath, target: CapabilityProxy.StoragePath)
        // ------------ END Setup CapabilityProxy

        // ------------ BEGIN Setup CapabilityFilter
        if acct.borrow<&{CapabilityFilter.Filter}>(from: CapabilityFilter.StoragePath) == nil {
            let filter <- CapabilityFilter.create(Type<@CapabilityFilter.AllowAllFilter>())
            acct.save(<-filter, to: CapabilityFilter.StoragePath)
        }

        if !acct.getCapability<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath).check() {
            acct.unlink(CapabilityFilter.PublicPath)
            acct.link<&CapabilityFilter.AllowAllFilter{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath, target: CapabilityFilter.StoragePath)
        }

        let filterCap = acct.getCapability<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        assert(filterCap.check(), message: "failed to configure capability filter")
        // ------------ END Setup CapabilityFilter

        // ------------ BEGIN Load Capability Factory

        let factoryManagerCap = getAccount(factoryAddress).getCapability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath)

        // ------------ END Load Capability Factory

        let a <- RestrictedChildAccount.createRestrictedAccount(
            acctCap: self.authAccountCap,
            name: name,
            thumbnail: MetadataViews.HTTPFile(url: thumbnail),
            description: description,
            proxy: proxy,
            filter: filterCap,
            factoryManager: factoryManagerCap
        )

        let s <- RestrictedChildAccount.wrapAccount(<- a)

        // we need to save the wrapped account so that our parent can redeem it
        acct.save(<-s, to: RestrictedChildAccount.SharedAccountStoragePath)
        acct.link<&RestrictedChildAccount.SharedAccount>(RestrictedChildAccount.SharedAccountPrivatePath, target: RestrictedChildAccount.SharedAccountStoragePath)
        let cap = acct.getCapability<&RestrictedChildAccount.SharedAccount>(RestrictedChildAccount.SharedAccountPrivatePath)

        // Publish for the specified Address
        acct.inbox.publish(cap, name: RestrictedChildAccount.InboxName, recipient: parent)
    }
}
 
```

### Setup Manager
```cadence
import "RestrictedChildAccount"

transaction {
    prepare(acct: AuthAccount) {
        if acct.borrow<&RestrictedChildAccount.Manager>(from: RestrictedChildAccount.StoragePath) == nil {
            let m <- RestrictedChildAccount.createManager()
            acct.save(<-m, to: RestrictedChildAccount.StoragePath)
        }

        acct.unlink(RestrictedChildAccount.PublicPath)
        acct.link<&RestrictedChildAccount.Manager{RestrictedChildAccount.ManagerPublic}>(RestrictedChildAccount.PublicPath, target: RestrictedChildAccount.StoragePath)
    }
}
```

### Claim account published to signer
```cadence
import "RestrictedChildAccount"
import "MetadataViews"

transaction(childAddress: Address) {
  let managerRef: &RestrictedChildAccount.Manager
  let sharedAccount: &RestrictedChildAccount.SharedAccount

  prepare(signer: AuthAccount) {
    if signer.borrow<&RestrictedChildAccount.Manager>(from: RestrictedChildAccount.StoragePath) == nil {
      signer.save(<-RestrictedChildAccount.createManager(), to: RestrictedChildAccount.StoragePath)
    }

    if !signer.getCapability<&RestrictedChildAccount.Manager{RestrictedChildAccount.ManagerPublic}>(RestrictedChildAccount.PublicPath).check() {
        signer.unlink(RestrictedChildAccount.PublicPath)
        signer.link<&RestrictedChildAccount.Manager{RestrictedChildAccount.ManagerPublic}>(
            RestrictedChildAccount.PublicPath,
            target: RestrictedChildAccount.StoragePath
        )
    }

    self.managerRef = signer.borrow<&RestrictedChildAccount.Manager>(from: RestrictedChildAccount.StoragePath)!
    let cap = signer.inbox.claim<&RestrictedChildAccount.SharedAccount>(
        RestrictedChildAccount.InboxName,
        provider: childAddress
      ) ?? panic(
        "No SharedAccount Capability available from given provider"
        .concat(childAddress.toString())
        .concat(" with name ")
        .concat(RestrictedChildAccount.InboxName)
      )
    assert(cap.check(), message: "Published capability check failed")

    self.sharedAccount = cap.borrow() ?? panic("no shared account found")
  }

  execute {
    let a <- self.sharedAccount.pop()
    self.managerRef.registerAccount(<- a)
  }
}
```

### Withdraw NFT from child to parent
```cadence
import "RestrictedChildAccount"

import "NonFungibleToken"
import "MetadataViews"

import "ExampleNFT"

transaction(childName: String, id: UInt64) {
    let provider: &{NonFungibleToken.Provider}
    let receiver: &{NonFungibleToken.CollectionPublic}

    prepare(acct: AuthAccount) {
        let d = ExampleNFT.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

        let manager = acct.borrow<&RestrictedChildAccount.Manager>(from: RestrictedChildAccount.StoragePath) ?? panic("manager not found")
        let account = manager.borrowByName(name: childName) ?? panic("child account not found")
        let cap = account.getPrivateCap(path: d.providerPath, type: Type<&{NonFungibleToken.Provider}>()) ?? panic("no cap found")
        let providerCap = cap as! Capability<&{NonFungibleToken.Provider}>
        self.provider = providerCap.borrow() ?? panic("provider not found")

        self.receiver = acct.borrow<&{NonFungibleToken.CollectionPublic}>(from: d.storagePath) ?? panic("collection not found")
    }

    execute {
        let nft <- self.provider.withdraw(withdrawID: id)
        self.receiver.deposit(token: <-nft)
    }
}
```

### Setup Proxy
```cadence
import "CapabilityProxy"

transaction {
    prepare(acct: AuthAccount) {
        if acct.borrow<&CapabilityProxy.Proxy>(from: CapabilityProxy.StoragePath) == nil {
            let proxy <- CapabilityProxy.createProxy()
            acct.save(<-proxy, to: CapabilityProxy.StoragePath)
        }

        acct.unlink(CapabilityProxy.PublicPath)
        acct.unlink(CapabilityProxy.PrivatePath)

        acct.link<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic}>(CapabilityProxy.PublicPath, target: CapabilityProxy.StoragePath)
        acct.link<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic, CapabilityProxy.GetterPrivate}>(CapabilityProxy.PrivatePath, target: CapabilityProxy.StoragePath)
    }
}
```

### Add Public NFT Collection to Proxy
```cadence
import "CapabilityProxy"

import "NonFungibleToken"
import "ExampleNFT"

transaction {
    prepare(acct: AuthAccount) {
        let proxy = acct.borrow<&CapabilityProxy.Proxy>(from: CapabilityProxy.StoragePath)
            ?? panic("proxy not found")

        let sharedCap  = 
            acct.getCapability<&ExampleNFT.Collection{ExampleNFT.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)

        proxy.addCapability(cap: sharedCap, isPublic: true)
    }
}
```


## Example scripts

### Borrow CollectionPublic
```cadence
import "RestrictedChildAccount"

import "NonFungibleToken"
import "MetadataViews"

import "ExampleNFT"
   
pub fun main(parent: Address, childName: String): Bool {
    let d = ExampleNFT.resolveView(Type<MetadataViews.NFTCollectionData>())! as! MetadataViews.NFTCollectionData

    let acct = getAuthAccount(parent)
    let m = acct.borrow<&RestrictedChildAccount.Manager>(from: RestrictedChildAccount.StoragePath)
        ?? panic("Manager not found")

    let child = m.borrowByNamePublic(name: childName) ?? panic("account not found with given name: ".concat(childName))

    let collection = child.getCollectionPublicCap(path: d.publicPath).borrow()
        ?? panic("could not borrow public collection")

    return true
}
```

### Has Child Account
```cadence
import "RestrictedChildAccount"
import "MetadataViews"

pub fun main(addr: Address, childAddress: Address, name: String): Bool {
    let acct = getAuthAccount(addr)
    let manager = acct.borrow<&RestrictedChildAccount.Manager>(from: RestrictedChildAccount.StoragePath) ?? panic("manager not found")

    let child = manager.borrowByNamePublic(name: name) ?? panic("child not found")
    let display = child.resolveView(Type<MetadataViews.Display>())! as! MetadataViews.Display

    return display.name == name && child.getAccountAddress() == childAddress
}
```

### Find NFT Collection in proxy
```cadnece
import "CapabilityProxy"

import "NonFungibleToken"
import "ExampleNFT"

pub fun main(addr: Address): Bool {
    let acct = getAccount(addr)

    let proxy = 
        acct.getCapability<&CapabilityProxy.Proxy{CapabilityProxy.GetterPublic}>(CapabilityProxy.PublicPath).borrow()
        ?? panic("could not borrow proxy")

    let desiredType = Type<Capability<&ExampleNFT.Collection{ExampleNFT.ExampleNFTCollectionPublic}>>()
    let foundType = proxy.findFirstPublicType(desiredType) ?? panic("no type found")
    
    let nakedCap = proxy.getPublicCapability(foundType) ?? panic("requested capability type was not found")

    // we don't need to do anything with this cap, being able to cast here is enough to know
    // that this works
    let cap = nakedCap as! Capability<&{ExampleNFT.ExampleNFTCollectionPublic}>
    
    return true
}
```



