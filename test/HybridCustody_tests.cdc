import Test

pub var accounts: {String: Test.Account} = {}
pub var blockchain = Test.newEmulatorBlockchain()
pub let fungibleTokenAddress: Address = 0xee82856bf20e2aa6
pub let flowTokenAddress: Address = 0x0ae53cb6e3f42a79

pub let app = "app"
pub let child = "child"
pub let nftFactory = "nftFactory"

pub let exampleNFT = "ExampleNFT"
pub let exampleNFT2 = "ExampleNFT2"
pub let exampleToken = "ExampleToken"
pub let capabilityFilter = "CapabilityFilter"

pub let FilterKindAll = "all"
pub let FilterKindAllowList = "allowlist"
pub let FilterKindDenyList = "denylist"

pub let exampleNFTPublicIdentifier = "ExampleNFTCollection"
pub let exampleNFT2PublicIdentifier = "ExampleNFT2Collection"



// --------------- Test cases --------------- 

pub fun testImports() {
    let res = scriptExecutor("test_imports.cdc", [])! as! Bool
    assert(res, message: "import test failed")
}

pub fun testSetupFactory() {
    let tmp = blockchain.createAccount()
    setupFactoryManager(tmp)
    setupNFTCollection(tmp)

    scriptExecutor("factory/get_provider_from_factory.cdc", [tmp.address])
}

pub fun testSetupFactoryWithFT() {
    let tmp = blockchain.createAccount()
    setupFactoryManager(tmp)

    scriptExecutor("factory/get_ft_provider_from_factory.cdc", [tmp.address])
}

pub fun testSetupChildAccount() {
    let tmp = blockchain.createAccount()
    setupOwnedAccount(tmp, FilterKindAll)
}

pub fun testPublishAccount() {
    let tmp = blockchain.createAccount()
    setupOwnedAccount(tmp, FilterKindAll)

    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    let parent = blockchain.createAccount()

    txExecutor("hybrid-custody/publish_to_parent.cdc", [tmp], [parent.address, factory.address, filter.address], nil, nil)

    scriptExecutor("hybrid-custody/get_collection_from_inbox.cdc", [parent.address, tmp.address])
}

pub fun testRedeemAccount() {
    let child = blockchain.createAccount()
    setupOwnedAccount(child, FilterKindAll)

    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    let parent = blockchain.createAccount()

    txExecutor("hybrid-custody/publish_to_parent.cdc", [child], [parent.address, factory.address, filter.address], nil, nil)

    setupAccountManager(parent)
    txExecutor("hybrid-custody/redeem_account.cdc", [parent], [child.address, nil, nil], nil, nil)

    scriptExecutor("hybrid-custody/has_address_as_child.cdc", [parent.address, child.address])
}

pub fun testChildAccount_getAddress() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    scriptExecutor("hybrid-custody/verify_child_address.cdc", [parent.address, child.address])
}

pub fun testOwnedAccount_hasChildAccounts() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    assert(
        !(scriptExecutor("hybrid-custody/has_child_accounts.cdc", [parent.address]) as! Bool?)!,
        message: "parent should not have child accounts before explicitly configured"
    )

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    assert(
        (scriptExecutor("hybrid-custody/has_child_accounts.cdc", [parent.address]) as! Bool?)!,
        message: "parent should have child accounts after configured"
    )
}

pub fun testChildAccount_getFTCapability() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupFTProvider(child)
    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    scriptExecutor("hybrid-custody/get_ft_provider_capability.cdc", [parent.address, child.address])
}

pub fun testChildAccount_getCapability() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)

    scriptExecutor("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child.address])
}

pub fun testChildAccount_getPublicCapability() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)

    scriptExecutor("hybrid-custody/get_nft_collection_public_capability.cdc", [parent.address, child.address])
}

pub fun testCreateManagerWithInvalidFilterFails() {
    let parent = blockchain.createAccount()

    let error = expectScriptFailure("test/create_manager_with_invalid_filter.cdc", [parent.address])
    assert(
        contains(error, "Invalid CapabilityFilter Filter capability provided"),
        message: "Manager init did not fail as expected on invalid Filter Capability"
    )
}

pub fun testCheckParentRedeemedStatus() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()
    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    setupOwnedAccount(child, FilterKindAll)

    setupAccountManager(parent)
    assert(!isParent(child: child, parent: parent), message: "parent is already pending")

    txExecutor("hybrid-custody/publish_to_parent.cdc", [child], [parent.address, factory.address, filter.address], nil, nil)
    assert(isParent(child: child, parent: parent), message: "parent is already pending")

    txExecutor("hybrid-custody/redeem_account.cdc", [parent], [child.address, nil, nil], nil, nil)
    assert(checkIsRedeemed(child: child, parent: parent), message: "parents was redeemed but is not marked properly")
}

pub fun testSeal() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let numKeysBefore = getNumValidKeys(child)
    assert(numKeysBefore > 0, message: "no keys to revoke")
    assert(checkAuthAccountDefaultCap(account: child), message: "Missing Auth Account Capability at default path")

    let owner = getOwner(child: child)
    assert(owner! == child.address, message: "mismatched owner")

    txExecutor("hybrid-custody/relinquish_ownership.cdc", [child], [], nil, nil)
    let numKeysAfter = getNumValidKeys(child)
    assert(numKeysAfter == 0, message: "not all keys were revoked")
    assert(!checkAuthAccountDefaultCap(account: child), message: "Found Auth Account Capability at default path")
    let ownerAfter = getOwner(child: child)
    assert(ownerAfter == nil, message: "should not have an owner anymore")
}

pub fun testTransferOwnership() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let owner = blockchain.createAccount()
    setupAccountManager(owner)

    assert(
        !(scriptExecutor("hybrid-custody/has_owned_accounts.cdc", [owner.address]) as! Bool?)!,
        message: "owner should not have owned accounts before transfer"
    )

    txExecutor("hybrid-custody/transfer_ownership.cdc", [child], [owner.address], nil, nil)
    assert(getPendingOwner(child: child)! == owner.address, message: "child account pending ownership was not updated correctly")

    txExecutor("hybrid-custody/accept_ownership.cdc", [owner], [child.address, nil, nil], nil, nil)
    assert(getOwner(child: child)! == owner.address, message: "child account ownership is not correct")
    assert(getPendingOwner(child: child) == nil, message: "pending owner was not cleared after claiming ownership")

    assert(
        (scriptExecutor("hybrid-custody/has_owned_accounts.cdc", [owner.address]) as! Bool?)!,
        message: "parent should have owned accounts after transfer"
    )
}

pub fun testTransferOwnershipFromManager() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let owner = blockchain.createAccount()
    setupAccountManager(owner)

    assert(
        !(scriptExecutor("hybrid-custody/has_owned_accounts.cdc", [owner.address]) as! Bool?)!,
        message: "owner should not have owned accounts before transfer"
    )

    txExecutor("hybrid-custody/transfer_ownership.cdc", [child], [owner.address], nil, nil)
    assert(getPendingOwner(child: child)! == owner.address, message: "child account pending ownership was not updated correctly")

    txExecutor("hybrid-custody/accept_ownership.cdc", [owner], [child.address, nil, nil], nil, nil)
    assert(getOwner(child: child)! == owner.address, message: "child account ownership is not correct")
    assert(getPendingOwner(child: child) == nil, message: "pending owner was not cleared after claiming ownership")

    assert(
        (scriptExecutor("hybrid-custody/has_owned_accounts.cdc", [owner.address]) as! Bool?)!,
        message: "parent should have owned accounts after transfer"
    )

    let newOwner = blockchain.createAccount()
    setupAccountManager(newOwner)

    assert(
        !(scriptExecutor("hybrid-custody/has_owned_accounts.cdc", [newOwner.address]) as! Bool?)!,
        message: "owner should not have owned accounts before transfer"
    )

    txExecutor("hybrid-custody/transfer_ownership_from_manager.cdc", [owner], [child.address, newOwner.address], nil, nil)
    assert(getPendingOwner(child: child)! == newOwner.address, message: "child account pending ownership was not updated correctly")

    txExecutor("hybrid-custody/accept_ownership.cdc", [newOwner], [child.address, nil, nil], nil, nil)
    assert(getOwner(child: child)! == newOwner.address, message: "child account ownership is not correct")
    assert(getPendingOwner(child: child) == nil, message: "pending owner was not cleared after claiming ownership")
}

pub fun testGetCapability_ManagerFilterAllowed() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)

    scriptExecutor("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child.address])

    let filter = getTestAccount(FilterKindAllowList)
    setupFilter(filter, FilterKindAllowList)

    let nftIdentifier = buildTypeIdentifier(getTestAccount(exampleNFT), exampleNFT, "Collection")
    setManagerFilterOnChild(child: child, parent: parent, filterAddress: filter.address)

    let error = expectScriptFailure("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child.address])
    assert(contains(error, "Capability is not allowed by this account's Parent"), message: "failed to find expected error message")

    addTypeToFilter(filter, FilterKindAllowList, nftIdentifier)
    scriptExecutor("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child.address])
}

pub fun testGetCapability_ManagerFilterNotAllowed() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)

    scriptExecutor("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child.address])

    let filter = getTestAccount(FilterKindDenyList)
    setupFilter(filter, FilterKindDenyList)

    let nftIdentifier = buildTypeIdentifier(getTestAccount(exampleNFT), exampleNFT, "Collection")
    addTypeToFilter(filter, FilterKindDenyList, nftIdentifier)
    setManagerFilterOnChild(child: child, parent: parent, filterAddress: filter.address)

    let error = expectScriptFailure("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child.address])
    assert(contains(error, "Capability is not allowed by this account's Parent"), message: "failed to find expected error message")
}

pub fun testGetPrivateCapabilityFromDelegator() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let isPublic = false
    setupNFTCollection(child)
    addNFTCollectionToDelegator(child: child, parent: parent, isPublic: isPublic)

    scriptExecutor("hybrid-custody/get_examplenft_collection_from_delegator.cdc", [parent.address, child.address, isPublic])
}

pub fun testGetPublicCapabilityFromChild() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let isPublic = true
    setupNFTCollection(child)
    addNFTCollectionToDelegator(child: child, parent: parent, isPublic: isPublic)

    scriptExecutor("hybrid-custody/get_examplenft_collection_from_delegator.cdc", [parent.address, child.address, isPublic])
}

pub fun testMetadata_ChildAccount_Metadata() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let name = "my name"
    let desc = "lorem ipsum"
    let url = "http://example.com/image.png"
    txExecutor("hybrid-custody/metadata/set_child_account_display.cdc", [parent], [child.address, name, desc, url], nil, nil)

    let resolvedName = scriptExecutor("hybrid-custody/metadata/resolve_child_display_name.cdc", [parent.address, child.address])! as! String
    assert(name == resolvedName, message: "names do not match")

    // set it again to make sure overrides work
    let name2 = "another name"
    txExecutor("hybrid-custody/metadata/set_child_account_display.cdc", [parent], [child.address, name2, desc, url], nil, nil)
    let resolvedName2 = scriptExecutor("hybrid-custody/metadata/resolve_child_display_name.cdc", [parent.address, child.address])! as! String
    assert(name2 == resolvedName2, message: "names do not match")
}

pub fun testMetadata_OwnedAccount_Metadata() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let name = "my name"
    let desc = "lorem ipsum"
    let url = "http://example.com/image.png"
    txExecutor("hybrid-custody/metadata/set_owned_account_display.cdc", [child], [name, desc, url], nil, nil)

    let resolvedName = scriptExecutor("hybrid-custody/metadata/resolve_owned_display_name.cdc", [child.address])! as! String
    assert(name == resolvedName, message: "names do not match")

    // set it again to make sure overrides work
    let name2 = "another name"
    txExecutor("hybrid-custody/metadata/set_owned_account_display.cdc", [child], [name2, desc, url], nil, nil)
    let resolvedName2 = scriptExecutor("hybrid-custody/metadata/resolve_owned_display_name.cdc", [child.address])! as! String
    assert(name2 == resolvedName2, message: "names do not match")
}

pub fun testGetChildAddresses() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)
    checkForAddresses(child: child, parent: parent)
}

pub fun testRemoveChildAccount() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)
    checkForAddresses(child: child, parent: parent)


    assert(isParent(child: child, parent: parent) == true, message: "is not parent of child account")
    txExecutor("hybrid-custody/remove_child_account.cdc", [parent], [child.address], nil, nil)
    assert(isParent(child: child, parent: parent) == false, message: "child account was not removed from parent")
}

pub fun testGetAllFlowBalances() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let expectedChildBal = (scriptExecutor("test/get_flow_balance.cdc", [child.address]) as! UFix64?)!
    let expectedParentBal = (scriptExecutor("test/get_flow_balance.cdc", [parent.address]) as! UFix64?)!

    let result = (scriptExecutor("hybrid-custody/get_all_flow_balances.cdc", [parent.address]) as! {Address: UFix64}?)!

    assert(
        result.containsKey(child.address) && result[child.address] == expectedChildBal,
        message: "child Flow balance incorrectly reported"
    )

    assert(
        result.containsKey(parent.address) && result[parent.address] == expectedParentBal,
        message: "parent Flow balance incorrectly reported"
    )
}

pub fun testGetAllFTBalance() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let expectedChildBal = (scriptExecutor("test/get_flow_balance.cdc", [child.address]) as! UFix64?)!
    let expectedParentBal = (scriptExecutor("test/get_flow_balance.cdc", [parent.address]) as! UFix64?)!

    let result = (scriptExecutor("test/get_all_vault_bal_from_storage.cdc", [parent.address]) as! {Address: {String: UFix64}}?)!

    assert(
        result.containsKey(child.address) && result[child.address]!["A.0ae53cb6e3f42a79.FlowToken.Vault"] == expectedChildBal,
        message: "child Flow balance incorrectly reported"
    )

    assert(
        result.containsKey(parent.address) && result[parent.address]!["A.0ae53cb6e3f42a79.FlowToken.Vault"] == expectedParentBal,
        message: "parent Flow balance incorrectly reported"
    )
}

pub fun testGetFlowBalanceByStoragePath() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let expectedChildBal = (scriptExecutor("test/get_flow_balance.cdc", [child.address]) as! UFix64?)!
    let expectedParentBal = (scriptExecutor("test/get_flow_balance.cdc", [parent.address]) as! UFix64?)!

    let result = (scriptExecutor(
            "hybrid-custody/get_spec_balance_from_public.cdc",
            [parent.address, PublicPath(identifier: "flowTokenVault")!]
        ) as! {Address: UFix64}?)!

    assert(
        result.containsKey(child.address) && result[child.address] == expectedChildBal,
        message: "child Flow balance incorrectly reported"
    )
    assert(
        result.containsKey(parent.address) && result[parent.address] == expectedParentBal,
        message: "parent Flow balance incorrectly reported"
    )
}

pub fun testGetNFTDisplayViewFromPublic() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)
    setupNFTCollection(parent)

    mintNFTDefault(accounts[exampleNFT]!, receiver: child)
    mintNFTDefault(accounts[exampleNFT]!, receiver: parent)

    let expectedChildIDs = (scriptExecutor("example-nft/get_ids.cdc", [child.address]) as! [UInt64]?)!
    let expectedParentIDs = (scriptExecutor("example-nft/get_ids.cdc", [parent.address]) as! [UInt64]?)!

    let expectedAddressLength: Int = 2
    let expectedViewsLength: Int = 1
    let expectedAddressToIDs: {Address: [UInt64]} = {parent.address: expectedParentIDs, child.address: expectedChildIDs}

    scriptExecutor(
        "test/test_get_nft_display_view_from_public.cdc",
        [parent.address, PublicPath(identifier: exampleNFTPublicIdentifier)!, expectedAddressToIDs]
    )
}

pub fun testGetAllCollectionViewsFromStorage() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)
    setupNFTCollection(parent)

    mintNFTDefault(accounts[exampleNFT]!, receiver: child)
    mintNFTDefault(accounts[exampleNFT]!, receiver: parent)

    let expectedAddressLength: Int = 2
    let expectedViewsLength: Int = 1
    let expectedAddressToCollectionLength: {Address: Int} = {parent.address: expectedViewsLength, child.address: expectedViewsLength}

    scriptExecutor(
        "test/test_get_all_collection_data_from_storage.cdc",
        [parent.address, expectedAddressToCollectionLength]
    )
}

pub fun testSetupChildAndParentMultiSig() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    setupFilter(filter, FilterKindAll)
    setupFactoryManager(factory)

    txExecutor("hybrid-custody/setup_multi_sig.cdc", [child, parent], [filter.address, factory.address, filter.address], nil, nil)

    assert(isParent(child: child, parent: parent), message: "parent account not found")
}

pub fun testSendChildFtsWithParentSigner() {
    let parent = blockchain.createAccount()
    let child = blockchain.createAccount()
    let child2 = blockchain.createAccount()
    let exampleToken = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let mintAmount: UFix64 = 100.0
    let amount: UFix64 = 10.0
    setupFT(child2)
    setupFT(child)
    setupFTProvider(child)
    
    txExecutor("example-token/mint_tokens.cdc", [exampleToken], [child.address, mintAmount], nil, nil)
    let balance: UFix64? = getBalance(child)
    assert(balance == mintAmount, message: "balance should be".concat(mintAmount.toString()))

    let recipientBalanceBefore: UFix64? = getBalance(child2)
    assert(recipientBalanceBefore == 0.0, message: "recipient balance should be 0")

    txExecutor("hybrid-custody/send_child_ft_with_parent.cdc", [parent], [amount, child2.address, child.address], nil, nil)

    let recipientBalanceAfter: UFix64? = getBalance(child2)
    assert(recipientBalanceAfter == amount, message: "recipient balance should be".concat(amount.toString()))
}

pub fun testAddExampleTokenToBalance() {
    let child = blockchain.createAccount()
    let exampleToken = blockchain.createAccount()

    setupFT(child)

    let amount: UFix64 = 100.0
    txExecutor("example-token/mint_tokens.cdc", [exampleToken], [child.address, amount], nil, nil)

    let balance: UFix64? = getBalance(child)
    assert(balance == amount, message: "balance should be".concat(amount.toString()))
}

pub fun testSetupOwnedAccountWithDisplay() {
    let acct = blockchain.createAccount()

    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    setupFilter(filter, FilterKindAll)
    setupFactoryManager(factory)

    let name = "my name"
    let desc = "description"
    let thumbnail = "https://example.com/test.jpeg"

    txExecutor("hybrid-custody/setup_owned_account_with_display.cdc", [acct], [name, desc, thumbnail], nil, nil)
    assert(scriptExecutor("hybrid-custody/metadata/assert_owned_account_display.cdc", [acct.address, name, desc, thumbnail])! as! Bool, message: "failed to match display")
}

pub fun testGetChildAccountNFTCapabilities(){
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()
    let nftIdentifier = buildTypeIdentifier(getTestAccount(exampleNFT), exampleNFT, "Collection")
    let nftIdentifier2 = buildTypeIdentifier(getTestAccount(exampleNFT2), exampleNFT2, "Collection")
    
    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let isPublic = true
    setupNFT2Collection(child)
    addNFTCollectionToDelegator(child: child, parent: parent, isPublic: isPublic)
    addNFT2CollectionToDelegator(child: child, parent: parent, isPublic: isPublic)

    let nftTypeIds = scriptExecutor("hybrid-custody/get_child_account_nft_capabilities.cdc", [parent.address])! as! {Address: [String]}
    assert(
        nftTypeIds.containsKey(child.address) && nftTypeIds[child.address]!.contains(nftIdentifier),
        message: "typeId should be: ".concat(nftIdentifier)
    )
    assert(
        nftTypeIds.containsKey(child.address) && nftTypeIds[child.address]!.contains(nftIdentifier2),
        message: "typeId should be: ".concat(nftIdentifier2)
    )
}

pub fun testGetNFTsAccessibleFromChildAccount(){
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()
    let nftIdentifier = buildTypeIdentifier(getTestAccount(exampleNFT), exampleNFT, "Collection")
    let nftIdentifier2 = buildTypeIdentifier(getTestAccount(exampleNFT2), exampleNFT2, "Collection")
    
    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)
    setupNFT2Collection(child)

    mintNFTDefault(accounts[exampleNFT]!, receiver: child)

    let expectedChildIDs = (scriptExecutor("example-nft/get_ids.cdc", [child.address]) as! [UInt64]?)!
    let expectedParentIDs: [UInt64] = []
    let expectedAddressToIDs: {Address: [UInt64]} = {child.address: expectedChildIDs, parent.address: expectedParentIDs}

    scriptExecutor(
        "test/test_get_nft_display_view_from_public.cdc",
        [parent.address, PublicPath(identifier: exampleNFTPublicIdentifier)!, expectedAddressToIDs]
    )

    // Test we have capabilities to access the minted NFTs
    scriptExecutor("test/test_get_accessible_child_nfts.cdc", [
        parent.address,
        {child.address: expectedChildIDs} as! {Address: [UInt64]}
    ])
    
    // Mint new nfts from ExampleNFT2 and assert that get_accessible_child_nfts.cdc does not return these nfts.
    mintExampleNFT2Default(accounts[exampleNFT2]!, receiver: child)
    let expectedChildIDs2 = (scriptExecutor("example-nft-2/get_ids.cdc", [child.address]) as! [UInt64]?)!
    let expectedAddressToIDs2: {Address: [UInt64]} = {child.address: expectedChildIDs2, parent.address: expectedParentIDs}

    scriptExecutor(
        "test/test_get_nft_display_view_from_public.cdc",
        [parent.address, PublicPath(identifier: exampleNFT2PublicIdentifier)!, expectedAddressToIDs2]
    )

    // revoke the ExampleNFT2 provider capability, preventing it from being returned.
    let paths: [CapabilityPath] = [
        /private/exampleNFT2Collection,
        /private/exampleNFTCollection
    ]
    txExecutor("misc/unlink_paths.cdc", [child], [paths], nil, nil)

    let expectedAddressToIDsFails: {Address: [UInt64]} = {child.address: expectedChildIDs2}
    let error = expectScriptFailure("test/test_get_accessible_child_nfts.cdc", [parent.address, expectedAddressToIDsFails])
    assert(contains(error, "Resulting ID does not match expected ID!"), message: "failed to find expected error message")
}

pub fun testGetChildAccountFTCapabilities(){
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()
    let nftIdentifier = buildTypeIdentifier(getTestAccount(exampleToken), exampleToken, "Vault")

    setupChildAndParent_FilterKindAll(child: child, parent: parent)
    setupFTProvider(child)

    let ftTypeIds = scriptExecutor("hybrid-custody/get_child_account_ft_capabilities.cdc", [parent.address])! as! {Address: [String]}
    assert(ftTypeIds[child.address]![0] == nftIdentifier, message: "typeId should be: ".concat(nftIdentifier))

}

pub fun testBlockchainNativeOnboarding() {
    let filter = getTestAccount(FilterKindAll)
    let factory = getTestAccount(nftFactory)

    setupFilter(filter, FilterKindAll)
    setupFactoryManager(factory)

    let app = blockchain.createAccount()
    let parent = blockchain.createAccount()
    
    let pubKeyStr = "1290b0382db250ffb4c2992039b1c9ed3b60e15afd4181ee0e0b9d5263e3a8aef4e91b1214f7baa44e30a31a1ce83489d37d5b0af64d848f4e2ce4e89818059e"
    let expectedPubKey = PublicKey(
            publicKey: pubKeyStr.decodeHex(),
            signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
        )

    txExecutor("hybrid-custody/onboarding/blockchain_native.cdc", [parent, app], [pubKeyStr, 0.0, factory.address, filter.address], nil, nil)

    let childAddresses = scriptExecutor("hybrid-custody/get_child_addresses.cdc", [parent.address]) as! [Address]?
        ?? panic("problem adding blockchain native child account to signing parent")
    let child = Test.Account(address: childAddresses[0], publicKey: expectedPubKey)
    
    assert(checkForAddresses(child: child, parent: parent), message: "child account not linked to parent")
}

pub fun testSetDefaultManagerFilter() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)
    setupNFTCollection(child)

    scriptExecutor("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child.address])

    let filter = getTestAccount(FilterKindDenyList)
    setupFilter(filter, FilterKindDenyList)

    txExecutor("hybrid-custody/set_default_manager_cap.cdc", [parent], [filter.address], nil, nil)

    let child2 = blockchain.createAccount()
    setupChildAndParent_FilterKindAll(child: child2, parent: parent)
    setupNFTCollection(child2)

    let nftIdentifier = buildTypeIdentifier(getTestAccount(exampleNFT), exampleNFT, "Collection")
    addTypeToFilter(filter, FilterKindDenyList, nftIdentifier)

    let error = expectScriptFailure("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child2.address])
    assert(contains(error, "Capability is not allowed by this account's Parent"), message: "failed to find expected error message")
}

pub fun testPublishToParent_alreadyExists() {
    let tmp = blockchain.createAccount()
    setupOwnedAccount(tmp, FilterKindAll)

    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    let parent = blockchain.createAccount()

    // put a resource in the ChildAccount storage slot for the parent to guarantee that publishing will not work
    txExecutor("hybrid-custody/misc/save_resource_to_parent_child_storage_slot.cdc", [tmp], [parent.address], nil, nil)

    // this should fail because something is already stored where the child account is located
    txExecutor(
        "hybrid-custody/publish_to_parent.cdc",
        [tmp],
        [parent.address, factory.address, filter.address],
        "conflicting resource found in child account storage slot for parentAddress",
        ErrorType.TX_ASSERT
    )
}

pub fun testRemoveParent() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)
    
    // remove the parent and validate the the parent manager resource doesn't have the child anymore
    txExecutor("hybrid-custody/remove_parent_from_child.cdc", [child], [parent.address], nil, nil)
}

// --------------- End Test Cases --------------- 


// --------------- Transaction wrapper functions ---------------

pub fun setupChildAndParent_FilterKindAll(child: Test.Account, parent: Test.Account) {
    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    setupOwnedAccount(child, FilterKindAll)

    setupAccountManager(parent)

    txExecutor("hybrid-custody/publish_to_parent.cdc", [child], [parent.address, factory.address, filter.address], nil, nil)

    txExecutor("hybrid-custody/redeem_account.cdc", [parent], [child.address, nil, nil], nil, nil)
}

pub fun setupAccountManager(_ acct: Test.Account) {
    txExecutor("hybrid-custody/setup_manager.cdc", [acct], [nil, nil], nil, nil)
}

pub fun setAccountManagerWithFilter(_ acct: Test.Account, _ filterAccount: Test.Account) {
    txExecutor("hybrid-custody/setup_manager.cdc", [acct], [nil, nil], nil, nil)
}

pub fun setManagerFilterOnChild(child: Test.Account, parent: Test.Account, filterAddress: Address) {
    txExecutor("hybrid-custody/set_manager_filter_cap.cdc", [parent], [filterAddress, child.address], nil, nil)
}

pub fun setupOwnedAccount(_ acct: Test.Account, _ filterKind: String) {
    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(filterKind)

    setupFilter(filter, filterKind)
    setupFactoryManager(factory)

    setupNFTCollection(acct)
    setupFT(acct)


    txExecutor("hybrid-custody/setup_owned_account.cdc", [acct], [], nil, nil)
}

pub fun setupFactoryManager(_ acct: Test.Account) {
    txExecutor("factory/setup.cdc", [acct], [], nil, nil)
}

pub fun setupNFTCollection(_ acct: Test.Account) {
    txExecutor("example-nft/setup_full.cdc", [acct], [], nil, nil)
}

pub fun setupNFT2Collection(_ acct: Test.Account) {
    txExecutor("example-nft-2/setup_full.cdc", [acct], [], nil, nil)
}

pub fun mintNFT(_ minter: Test.Account, receiver: Test.Account, name: String, description: String, thumbnail: String) {
    let filepath: String = "example-nft/mint_to_account.cdc"
    txExecutor(filepath, [minter], [receiver.address, name, description, thumbnail], nil, nil)
}

pub fun mintNFTDefault(_ minter: Test.Account, receiver: Test.Account) {
    return mintNFT(minter, receiver: receiver, name: "example nft", description: "lorem ipsum", thumbnail: "http://example.com/image.png")
}

pub fun mintExampleNFT2(_ minter: Test.Account, receiver: Test.Account, name: String, description: String, thumbnail: String) {
    let filepath: String = "example-nft-2/mint_to_account.cdc"
    txExecutor(filepath, [minter], [receiver.address, name, description, thumbnail], nil, nil)
}

pub fun mintExampleNFT2Default(_ minter: Test.Account, receiver: Test.Account) {
    return mintExampleNFT2(minter, receiver: receiver, name: "example nft 2", description: "lorem ipsum", thumbnail: "http://example.com/image.png")
}

pub fun setupFT(_ acct: Test.Account) {
    txExecutor("example-token/setup.cdc", [acct], [], nil, nil)
}

pub fun setupFTProvider(_ acct: Test.Account) {
    txExecutor("example-token/setup_provider.cdc", [acct], [], nil, nil)
}

pub fun setupFilter(_ acct: Test.Account, _ kind: String) {
    var filePath = ""
    switch kind {
        case FilterKindAll:
            filePath = "filter/setup_allow_all.cdc"
            break
        case FilterKindAllowList:
            filePath = "filter/allow/setup.cdc"
            break
        case FilterKindDenyList:
            filePath = "filter/deny/setup.cdc"
            break
        default:
            assert(false, message: "unknown filter kind given")
    }

    txExecutor(filePath, [acct], [], nil, nil)
}

pub fun addTypeToFilter(_ acct: Test.Account, _ kind: String, _ identifier: String) {
    var filePath = ""
    switch kind {
        case FilterKindAllowList:
            filePath = "filter/allow/add_type_to_list.cdc"
            break
        case FilterKindDenyList:
            filePath = "filter/deny/add_type_to_list.cdc"
            break
        default:
            assert(false, message: "unknown filter kind given")
    }

    txExecutor(filePath, [acct], [identifier], nil, nil)
}

pub fun addNFTCollectionToDelegator(child: Test.Account, parent: Test.Account, isPublic: Bool) {
    txExecutor("hybrid-custody/add_example_nft_collection_to_delegator.cdc", [child], [parent.address, isPublic], nil, nil)
}

pub fun addNFT2CollectionToDelegator(child: Test.Account, parent: Test.Account, isPublic: Bool) {
    txExecutor("hybrid-custody/add_example_nft2_collection_to_delegator.cdc", [child], [parent.address, isPublic], nil, nil)
}
// ---------------- End Transaction wrapper functions

// ---------------- Begin script wrapper functions

pub fun getParentStatusesForChild(_ child: Test.Account): {Address: Bool} {
    return scriptExecutor("hybrid-custody/get_parents_from_child.cdc", [child.address])! as! {Address: Bool}
}

pub fun isParent(child: Test.Account, parent: Test.Account): Bool {
    return scriptExecutor("hybrid-custody/is_parent.cdc", [child.address, parent.address])! as! Bool
}

pub fun checkIsRedeemed(child: Test.Account, parent: Test.Account): Bool {
    return scriptExecutor("hybrid-custody/is_redeemed.cdc", [child.address, parent.address])! as! Bool
}

pub fun getNumValidKeys(_ child: Test.Account): Int {
    return scriptExecutor("hybrid-custody/get_num_valid_keys.cdc", [child.address])! as! Int
}

pub fun checkAuthAccountDefaultCap(account: Test.Account): Bool {
    return scriptExecutor("hybrid-custody/check_default_auth_acct_linked_path.cdc", [account.address])! as! Bool
}

pub fun getOwner(child: Test.Account): Address? {
    let res = scriptExecutor("hybrid-custody/get_owner_of_child.cdc", [child.address])
    if res == nil {
        return nil
    }

    return res! as! Address
}

pub fun getPendingOwner(child: Test.Account): Address? {
    let res = scriptExecutor("hybrid-custody/get_pending_owner_of_child.cdc", [child.address])

    return res as! Address?
}

pub fun checkForAddresses(child: Test.Account, parent: Test.Account): Bool {
    let childAddressResult: [Address]? = (scriptExecutor("hybrid-custody/get_child_addresses.cdc", [parent.address])) as! [Address]?
    assert(childAddressResult?.contains(child.address) == true, message: "child address not found")

    let parentAddressResult: [Address]? = (scriptExecutor("hybrid-custody/get_parent_addresses.cdc", [child.address])) as! [Address]?
    assert(parentAddressResult?.contains(parent.address) == true, message: "parent address not found")
    return true
}

pub fun getBalance(_ acct: Test.Account): UFix64 {
    let balance: UFix64? = (scriptExecutor("example-token/get_balance.cdc", [acct.address])! as! UFix64)
    return balance!
}

// ---------------- End script wrapper functions

// ---------------- BEGIN General-purpose helper functions

pub fun buildTypeIdentifier(_ acct: Test.Account, _ contractName: String, _ suffix: String): String {
    let addrString = (acct.address as! Address).toString()
    return "A.".concat(addrString.slice(from: 2, upTo: addrString.length)).concat(".").concat(contractName).concat(".").concat(suffix)
}

pub fun getCapabilityFilterPath(): String {
    let filterAcct =  getTestAccount(capabilityFilter)

    return "CapabilityFilter".concat(filterAcct.address.toString())
}

// ---------------- END General-purpose helper functions

pub fun getTestAccount(_ name: String): Test.Account {
    if accounts[name] == nil {
        accounts[name] = blockchain.createAccount()
    }

    return accounts[name]!
}

pub fun loadCode(_ fileName: String, _ baseDirectory: String): String {
    return Test.readFile("../".concat(baseDirectory).concat("/").concat(fileName))
}

pub fun scriptExecutor(_ scriptName: String, _ arguments: [AnyStruct]): AnyStruct? {
    let scriptCode = loadCode(scriptName, "scripts")
    let scriptResult = blockchain.executeScript(scriptCode, arguments)
    var failureMessage = ""
    if let failureError = scriptResult.error {
        failureMessage = "Failed to execute the script because -:  ".concat(failureError.message)
    }

    assert(scriptResult.status == Test.ResultStatus.succeeded, message: failureMessage)
    return scriptResult.returnValue
}

pub fun expectScriptFailure(_ scriptName: String, _ arguments: [AnyStruct]): String {
    let scriptCode = loadCode(scriptName, "scripts")
    let scriptResult = blockchain.executeScript(scriptCode, arguments)

    assert(scriptResult.error != nil, message: "script error was expected but there is no error message")
    return scriptResult.error!.message
}

pub fun txExecutor(_ filePath: String, _ signers: [Test.Account], _ arguments: [AnyStruct], _ expectedError: String?, _ expectedErrorType: ErrorType?): Bool {
    let txCode = loadCode(filePath, "transactions")

    let authorizers: [Address] = []
    for s in signers {
        authorizers.append(s.address)
    }

    let tx = Test.Transaction(
        code: txCode,
        authorizers: authorizers,
        signers: signers,
        arguments: arguments,
    )

    let txResult = blockchain.executeTransaction(tx)
    if let err = txResult.error {
        if let expectedErrorMessage = expectedError {
            let ptr = getErrorMessagePointer(errorType: expectedErrorType!)
            let errMessage = err.message
            let hasEmittedCorrectMessage = contains(errMessage, expectedErrorMessage)
            let failureMessage = "Expecting - "
                .concat(expectedErrorMessage)
                .concat("\n")
                .concat("But received - ")
                .concat(err.message)
            assert(hasEmittedCorrectMessage, message: failureMessage)
            return true
        }
        panic(err.message)
    } else {
        if let expectedErrorMessage = expectedError {
            panic("Expecting error - ".concat(expectedErrorMessage).concat(". While no error triggered"))
        }
    }

    return txResult.status == Test.ResultStatus.succeeded
}

pub fun setup() {
    // main contract account being tested
    let linkedAccount = blockchain.createAccount()
    let hybridCustodyAccount = blockchain.createAccount()
    let capabilityDelegatorAccount = blockchain.createAccount()
    let capabilityFilterAccount = blockchain.createAccount()
    let capabilityFactoryAccount = blockchain.createAccount()

    // factory accounts
    let cpFactory = blockchain.createAccount()
    let providerFactory = blockchain.createAccount()
    let cpAndProviderFactory = blockchain.createAccount()
    let ftProviderFactory = blockchain.createAccount()

    // the account to store a factory manager
    let nftCapFactory = blockchain.createAccount()

    // flow-utils lib contracts
    let arrayUtils = blockchain.createAccount()
    let stringUtils = blockchain.createAccount()
    let addressUtils = blockchain.createAccount()

    // standard contracts
    let nonFungibleToken = blockchain.createAccount()
    let metadataViews = blockchain.createAccount()
    let viewResolver = blockchain.createAccount()
    
    // other contracts used in tests
    let exampleNFT = blockchain.createAccount()
    let exampleNFT2 = blockchain.createAccount()
    let exampleToken = blockchain.createAccount()

    
    // actual test accounts
    let parent = blockchain.createAccount()
    let child1 = blockchain.createAccount()
    let child2 = blockchain.createAccount()

    accounts = {
        "NonFungibleToken": nonFungibleToken,
        "MetadataViews": metadataViews,
        "ViewResolver": viewResolver,
        "HybridCustody": hybridCustodyAccount,
        "CapabilityDelegator": capabilityDelegatorAccount,
        "CapabilityFilter": capabilityFilterAccount,
        "CapabilityFactory": capabilityFactoryAccount,
        "NFTCollectionPublicFactory": cpFactory,
        "NFTProviderAndCollectionFactory": providerFactory,
        "NFTProviderFactory": cpAndProviderFactory,
        "FTProviderFactory": ftProviderFactory,
        "ArrayUtils": arrayUtils,
        "StringUtils": stringUtils,
        "AddressUtils": addressUtils,
        "ExampleNFT": exampleNFT,
        "ExampleNFT2": exampleNFT2,
        "ExampleToken": exampleToken,
        "parent": parent,
        "child1": child1,
        "child2": child2,
        "nftCapFactory": nftCapFactory
    }

    blockchain.useConfiguration(Test.Configuration({
        "FungibleToken": fungibleTokenAddress,
        "NonFungibleToken": accounts["NonFungibleToken"]!.address,
        "FlowToken": flowTokenAddress,
        "MetadataViews": accounts["MetadataViews"]!.address,
        "ViewResolver": accounts["ViewResolver"]!.address,
        "ArrayUtils": accounts["ArrayUtils"]!.address,
        "StringUtils": accounts["StringUtils"]!.address,
        "AddressUtils": accounts["AddressUtils"]!.address,
        "HybridCustody": accounts["HybridCustody"]!.address,
        "CapabilityDelegator": accounts["CapabilityDelegator"]!.address,
        "CapabilityFilter": accounts["CapabilityFilter"]!.address,
        "CapabilityFactory": accounts["CapabilityFactory"]!.address,
        "NFTCollectionPublicFactory": accounts["NFTCollectionPublicFactory"]!.address,
        "NFTProviderAndCollectionFactory": accounts["NFTProviderAndCollectionFactory"]!.address,
        "NFTProviderFactory": accounts["NFTProviderFactory"]!.address,
        "FTProviderFactory": accounts["FTProviderFactory"]!.address,
        "ExampleNFT": accounts["ExampleNFT"]!.address,
        "ExampleNFT2": accounts["ExampleNFT2"]!.address,
        "ExampleToken": accounts["ExampleToken"]!.address
    }))

    // deploy standard libs first
    deploy("NonFungibleToken", accounts["NonFungibleToken"]!, "../modules/flow-nft/contracts/NonFungibleToken.cdc")
    deploy("MetadataViews", accounts["MetadataViews"]!, "../modules/flow-nft/contracts/MetadataViews.cdc")
    deploy("ViewResolver", accounts["ViewResolver"]!, "../modules/flow-nft/contracts/ViewResolver.cdc")

    // helper libs in the order they are imported
    deploy("ArrayUtils", accounts["ArrayUtils"]!, "../modules/flow-utils/cadence/contracts/ArrayUtils.cdc")
    deploy("StringUtils", accounts["StringUtils"]!, "../modules/flow-utils/cadence/contracts/StringUtils.cdc")
    deploy("AddressUtils", accounts["AddressUtils"]!, "../modules/flow-utils/cadence/contracts/AddressUtils.cdc")

    // helper nft contract so we can actually talk to nfts with tests
    deploy("ExampleNFT", accounts["ExampleNFT"]!, "../modules/flow-nft/contracts/ExampleNFT.cdc")
    deploy("ExampleNFT2", accounts["ExampleNFT2"]!, "../contracts/standard/ExampleNFT2.cdc")
    deploy("ExampleToken", accounts["ExampleToken"]!, "../contracts/standard/ExampleToken.cdc")

    // our main contract is last
    deploy("CapabilityDelegator", accounts["CapabilityDelegator"]!, "../contracts/CapabilityDelegator.cdc")
    deploy("CapabilityFilter", accounts["CapabilityFilter"]!, "../contracts/CapabilityFilter.cdc")
    deploy("CapabilityFactory", accounts["CapabilityFactory"]!, "../contracts/CapabilityFactory.cdc")
    deploy("NFTCollectionPublicFactory", accounts["NFTCollectionPublicFactory"]!, "../contracts/factories/NFTCollectionPublicFactory.cdc")
    deploy("NFTProviderAndCollectionFactory", accounts["NFTProviderAndCollectionFactory"]!, "../contracts/factories/NFTProviderAndCollectionFactory.cdc")
    deploy("NFTProviderFactory", accounts["NFTProviderFactory"]!, "../contracts/factories/NFTProviderFactory.cdc")
    deploy("FTProviderFactory", accounts["FTProviderFactory"]!, "../contracts/factories/FTProviderFactory.cdc")
    deploy("HybridCustody", accounts["HybridCustody"]!, "../contracts/HybridCustody.cdc")
}

// BEGIN SECTION: Helper functions. All of the following were taken from
// https://github.com/onflow/Offers/blob/fd380659f0836e5ce401aa99a2975166b2da5cb0/lib/cadence/test/Offers.cdc
// - deploy
// - scriptExecutor
// - txExecutor
// - getErrorMessagePointer

pub fun deploy(_ contractName: String, _ account: Test.Account, _ path: String) {
 let contractCode = Test.readFile(path)
    let err = blockchain.deployContract(
        name: contractName,
        code: contractCode,
        account: account,
        arguments: [],
    )

    if err != nil {
        panic(err!.message)
    }
}

pub enum ErrorType: UInt8 {
    pub case TX_PANIC
    pub case TX_ASSERT
    pub case TX_PRE
}

pub fun getErrorMessagePointer(errorType: ErrorType) : Int {
    switch errorType {
        case ErrorType.TX_PANIC: return 159
        case ErrorType.TX_ASSERT: return 170
        case ErrorType.TX_PRE: return 174
        default: panic("Invalid error type")
    }

    return 0
}

// END SECTION: Helper functions
 

 // Copied functions from flow-utils so we can assert on error conditions
 // https://github.com/green-goo-dao/flow-utils/blob/main/cadence/contracts/StringUtils.cdc
pub fun contains(_ s: String, _ substr: String): Bool {
    if let index =  index(s, substr, 0) {
        return true
    }
    return false
}

 // https://github.com/green-goo-dao/flow-utils/blob/main/cadence/contracts/StringUtils.cdc
pub fun index(_ s : String, _ substr : String, _ startIndex: Int): Int?{
    for i in range(startIndex,s.length-substr.length+1){
        if s[i]==substr[0] && s.slice(from:i, upTo:i+substr.length) == substr{
            return i
        }
    }
    return nil
}

// https://github.com/green-goo-dao/flow-utils/blob/main/cadence/contracts/ArrayUtils.cdc
pub fun rangeFunc(_ start: Int, _ end: Int, _ f : ((Int):Void) ) {
    var current = start
    while current < end{
        f(current)
        current = current + 1
    }
}

pub fun range(_ start: Int, _ end: Int): [Int]{
    var res:[Int] = []
    rangeFunc(start, end, fun (i:Int){
        res.append(i)
    })
    return res
}
 