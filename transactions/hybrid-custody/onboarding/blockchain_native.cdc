#allowAccountLinking

import "FungibleToken"
import "FlowToken"
import "MetadataViews"

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

    prepare(parent: AuthAccount, app: AuthAccount) {
        /* --- Account Creation --- */
        //
        // Create the child account, funding via the signing app account
        let newAccount = AuthAccount(payer: app)
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
            let fundingProvider = app.borrow<&FlowToken.Vault{FungibleToken.Provider}>(
                    from: /storage/flowTokenVault
                )!
            // Fund the new account with the initialFundingAmount specified
            newAccount.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
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
        var acctCap = newAccount.linkAccount(HybridCustody.LinkedAccountPrivatePath)
            ?? panic("problem linking account Capability for new account")

        // Create a OwnedAccount & link Capabilities
        let ownedAccount <- HybridCustody.createOwnedAccount(acct: acctCap)
        newAccount.save(<-ownedAccount, to: HybridCustody.OwnedAccountStoragePath)
        newAccount
            .link<&HybridCustody.OwnedAccount{HybridCustody.BorrowableAccount, HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>(
                HybridCustody.OwnedAccountPrivatePath,
                target: HybridCustody.OwnedAccountStoragePath
            )
        newAccount
            .link<&HybridCustody.OwnedAccount{HybridCustody.OwnedAccountPublic}>(
                HybridCustody.OwnedAccountPublicPath, 
                target: HybridCustody.OwnedAccountStoragePath
            )

        // Get a reference to the OwnedAccount resource
        let owned = newAccount.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)!

        // Get the CapabilityFactory.Manager Capability
        let factory = getAccount(factoryAddress)
            .getCapability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>(
                CapabilityFactory.PublicPath
            )
        assert(factory.check(), message: "factory address is not configured properly")

        // Get the CapabilityFilter.Filter Capability
        let filter = getAccount(filterAddress).getCapability<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        assert(filter.check(), message: "capability filter is not configured properly")

        // Configure access for the delegatee parent account
        owned.publishToParent(parentAddress: parent.address, factory: factory, filter: filter)

        /* --- Add delegation to parent account --- */
        //
        // Configure HybridCustody.Manager if needed
        if parent.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) == nil {
            let m <- HybridCustody.createManager(filter: filter)
            parent.save(<- m, to: HybridCustody.ManagerStoragePath)
        }

        // Link Capabilities
        parent.unlink(HybridCustody.ManagerPublicPath)
        parent.unlink(HybridCustody.ManagerPrivatePath)
        parent.link<&HybridCustody.Manager{HybridCustody.ManagerPrivate, HybridCustody.ManagerPublic}>(
            HybridCustody.ManagerPrivatePath,
            target: HybridCustody.ManagerStoragePath
        )
        parent.link<&HybridCustody.Manager{HybridCustody.ManagerPublic}>(
            HybridCustody.ManagerPublicPath,
            target: HybridCustody.ManagerStoragePath
        )
        
        // Claim the ChildAccount Capability
        let inboxName = HybridCustody.getChildAccountIdentifier(parent.address)
        let cap = parent
            .inbox
            .claim<&HybridCustody.ChildAccount{HybridCustody.AccountPrivate, HybridCustody.AccountPublic, MetadataViews.Resolver}>(
                inboxName,
                provider: newAccount.address
            ) ?? panic("child account cap not found")
        
        // Get a reference to the Manager and add the account
        let managerRef = parent.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager no found")
        managerRef.addAccount(cap: cap)
    }
}
 