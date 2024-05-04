#allowAccountLinking

import "FungibleToken"
import "FlowToken"
import "MetadataViews"
import "ViewResolver"

import "HybridCustody"
import "CapabilityFactory"
import "CapabilityFilter"
import "CapabilityDelegator"

transaction(
    pubKey: String,
    initialFundingAmt: UFix64,
    factoryAddress: Address,
    filterAddress: Address
) {

    prepare(parent: auth(Storage, Capabilities, Inbox) &Account, app: auth(Storage, Capabilities) &Account) {
        /* --- Account Creation --- */
        //
        // Create the child account, funding via the signing app account
        let newAccount = Account(payer: app)
        // Create a public key for the child account from string value in the provided arg
        // **NOTE:** You may want to specify a different signature algo for your use case
        let key = PublicKey(
            publicKey: pubKey.decodeHex(),
            signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
        )
        // Add the key to the new account
        // **NOTE:** You may want to specify a different hash algo & weight best for your use case
        newAccount.keys.add(
            publicKey: key,
            hashAlgorithm: HashAlgorithm.SHA3_256,
            weight: 1000.0
        )

        /* --- (Optional) Additional Account Funding --- */
        //
        // Fund the new account if specified
        if initialFundingAmt > 0.0 {
            // Get a vault to fund the new account
            let fundingProvider = app.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>(from: /storage/flowTokenVault)!
            // Fund the new account with the initialFundingAmount specified
            newAccount.capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)!
                .borrow()!
                .deposit(
                    from: <-fundingProvider.withdraw(
                        amount: initialFundingAmt
                    )
                )
        }

        /* Continue with use case specific setup */
        //
        // At this point, the newAccount can further be configured as suitable for
        // use in your dapp (e.g. Setup a Collection, Mint NFT, Configure Vault, etc.)
        // ...

        /* --- Link the AuthAccount Capability --- */
        //
        let acctCap = newAccount.capabilities.account.issue<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>()

        // Create a OwnedAccount & link Capabilities
        let ownedAccount <- HybridCustody.createOwnedAccount(acct: acctCap)
        newAccount.storage.save(<-ownedAccount, to: HybridCustody.OwnedAccountStoragePath)

        newAccount.capabilities.storage.issue<&{HybridCustody.BorrowableAccount, HybridCustody.OwnedAccountPublic, ViewResolver.Resolver}>(HybridCustody.OwnedAccountStoragePath)
        newAccount.capabilities.publish(
            newAccount.capabilities.storage.issue<&{HybridCustody.OwnedAccountPublic, ViewResolver.Resolver}>(HybridCustody.OwnedAccountStoragePath),
            at: HybridCustody.OwnedAccountPublicPath
        )

        // Get a reference to the OwnedAccount resource
        let owned = newAccount.storage.borrow<auth(HybridCustody.Owner) &HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)!

        // Get the CapabilityFactory.Manager Capability
        let factory = getAccount(factoryAddress).capabilities
            .get<&{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath)!
        assert(factory.check(), message: "factory address is not configured properly")

        // Get the CapabilityFilter.Filter Capability
        let filter = getAccount(filterAddress).capabilities.get<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        assert(filter.check(), message: "capability filter is not configured properly")

        // Configure access for the delegatee parent account
        owned.publishToParent(parentAddress: parent.address, factory: factory, filter: filter)

        /* --- Add delegation to parent account --- */
        //
        // Configure HybridCustody.Manager if needed
        if parent.storage.borrow<&AnyResource>(from: HybridCustody.ManagerStoragePath) == nil {
            let m <- HybridCustody.createManager(filter: filter)
            parent.storage.save(<- m, to: HybridCustody.ManagerStoragePath)

            for c in parent.capabilities.storage.getControllers(forPath: HybridCustody.ManagerStoragePath) { 
                c.delete()
            }

            // configure Capabilities
            parent.capabilities.storage.issue<&{HybridCustody.ManagerPrivate, HybridCustody.ManagerPublic}>(HybridCustody.ManagerStoragePath)
            parent.capabilities.publish(
                parent.capabilities.storage.issue<&{HybridCustody.ManagerPublic}>(HybridCustody.ManagerStoragePath),
                at: HybridCustody.ManagerPublicPath
            )
        }

        
        // Claim the ChildAccount Capability
        let inboxName = HybridCustody.getChildAccountIdentifier(parent.address)
        let cap = parent
            .inbox
            .claim<auth(HybridCustody.Child) &{HybridCustody.AccountPrivate, HybridCustody.AccountPublic, ViewResolver.Resolver}>(
                inboxName,
                provider: newAccount.address
            ) ?? panic("child account cap not found")
        
        // Get a reference to the Manager and add the account
        let managerRef = parent.storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager no found")
        managerRef.addAccount(cap: cap)
    }
}
 