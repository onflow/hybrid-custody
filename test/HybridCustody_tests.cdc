import Test
import "test_helpers.cdc"
import "HybridCustody"
import "NonFungibleToken"
import "ExampleNFT"

access(all) let adminAccount = Test.getAccount(0x0000000000000007)
access(all) let accounts: {String: Test.TestAccount} = {}

access(all) let app = "app"
access(all) let child = "child"
access(all) let nftFactory = "nftFactory"

access(all) let exampleNFT = "ExampleNFT"
access(all) let exampleNFT2 = "ExampleNFT2"
access(all) let exampleToken = "ExampleToken"
access(all) let capabilityFilter = "CapabilityFilter"

access(all) let FilterKindAll = "all"
access(all) let FilterKindAllowList = "allowlist"
access(all) let FilterKindDenyList = "denylist"

access(all) let exampleNFTPublicIdentifier = "exampleNFTCollection"
access(all) let exampleNFT2PublicIdentifier = "exampleNFT2Collection"

// --------------- Test cases ---------------

access(all)
fun testImports() {
    let res = scriptExecutor("test_imports.cdc", [])! as! Bool
    Test.assert(res, message: "import test failed")
}

access(all)
fun testSetupFactory() {
    let tmp = Test.createAccount()
    setupFactoryManager(tmp)
    setupNFTCollection(tmp)

    scriptExecutor("factory/get_nft_provider_from_factory.cdc", [tmp.address])
}

access(all)
fun testSetupNFTFilterAndFactory() {
    let tmp = Test.createAccount()
    txExecutor("dev-setup/setup_nft_filter_and_factory_manager.cdc", [tmp], [accounts[exampleNFT]!.address, exampleNFT], nil)
    setupNFTCollection(tmp)

    scriptExecutor("factory/get_nft_provider_from_factory.cdc", [tmp.address])
    scriptExecutor("factory/get_nft_provider_from_factory_allowed.cdc", [tmp.address, tmp.address])
}

access(all)
fun testSetupFactoryWithFT() {
    let tmp = Test.createAccount()
    setupFactoryManager(tmp)

    txExecutor("example-token/setup.cdc", [tmp], [], nil)

    scriptExecutor("factory/get_ft_provider_from_factory.cdc", [tmp.address])
    scriptExecutor("factory/get_ft_balance_from_factory.cdc", [tmp.address])
    scriptExecutor("factory/get_ft_receiver_from_factory.cdc", [tmp.address])
}

access(all)
fun testSetupChildAccount() {
    let tmp = Test.createAccount()
    setupOwnedAccount(tmp, FilterKindAll)
}

access(all)
fun testPublishAccount() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupOwnedAccount(child, FilterKindAll)
    setupNFTCollection(child)

    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    txExecutor("hybrid-custody/publish_to_parent.cdc", [child], [parent.address, factory.address, filter.address], nil)

    scriptExecutor("hybrid-custody/get_collection_from_inbox.cdc", [parent.address, child.address])
}

access(all)
fun testRedeemAccount() {
    let child = Test.createAccount()
    setupOwnedAccount(child, FilterKindAll)

    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    let parent = Test.createAccount()

    txExecutor("hybrid-custody/publish_to_parent.cdc", [child], [parent.address, factory.address, filter.address], nil)

    setupAccountManager(parent)
    txExecutor("hybrid-custody/redeem_account.cdc", [parent], [child.address, nil, nil], nil)

    scriptExecutor("hybrid-custody/has_address_as_child.cdc", [parent.address, child.address])
}

access(all)
fun testSetupOwnedAccountAndPublishRedeemed() {
    let child = Test.createAccount()

    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    setupFilter(filter, FilterKindAll)
    setupFactoryManager(factory)

    let parent = Test.createAccount()

    txExecutor("hybrid-custody/setup_owned_account_and_publish_to_parent.cdc", [child], [parent.address, factory.address, filter.address, nil, nil, nil], nil)

    txExecutor("hybrid-custody/redeem_account.cdc", [parent], [child.address, nil, nil], nil)

    scriptExecutor("hybrid-custody/has_address_as_child.cdc", [parent.address, child.address])
}

access(all)
fun testSetupOwnedAccountWithDisplayPublishRedeemed() {
    let child = Test.createAccount()

    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    setupFilter(filter, FilterKindAll)
    setupFactoryManager(factory)

    let parent = Test.createAccount()

    let name = "Test"
    let desc = "Test description"
    let thumbnail = "https://example.com/test.jpeg"


    txExecutor(
        "hybrid-custody/setup_owned_account_and_publish_to_parent.cdc",
        [child],
        [parent.address, factory.address, filter.address, name, desc, thumbnail],
        nil
    )

    txExecutor("hybrid-custody/redeem_account.cdc", [parent], [child.address, nil, nil], nil)

    scriptExecutor("hybrid-custody/has_address_as_child.cdc", [parent.address, child.address])

    Test.assert(scriptExecutor("hybrid-custody/metadata/assert_owned_account_display.cdc", [child.address, name, desc, thumbnail])! as! Bool, message: "failed to match display")
}

access(all)
fun testChildAccount_getAddress() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    scriptExecutor("hybrid-custody/verify_child_address.cdc", [parent.address, child.address])
}

access(all)
fun testOwnedAccount_hasChildAccounts() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    Test.assert(
        !(scriptExecutor("hybrid-custody/has_child_accounts.cdc", [parent.address]) as! Bool?)!,
        message: "parent should not have child accounts before explicitly configured"
    )

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    Test.assert(
        (scriptExecutor("hybrid-custody/has_child_accounts.cdc", [parent.address]) as! Bool?)!,
        message: "parent should have child accounts after configured"
    )
}

access(all)
fun testChildAccount_getFTCapability() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupFTProvider(child)
    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    scriptExecutor("hybrid-custody/get_ft_provider_capability.cdc", [parent.address, child.address])
}

access(all)
fun testChildAccount_getCapability() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)

    scriptExecutor("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child.address])
}

access(all)
fun testChildAccount_getCapabilityReturnsNil() {
    let dev = Test.createAccount()
    let child = Test.createAccount()
    let parent = Test.createAccount()

    // Setup NFT Filter & Factory
    txExecutor("dev-setup/setup_nft_filter_and_factory_manager.cdc", [dev], [accounts[exampleNFT]!.address, exampleNFT], nil)
    // Setup OwnedAccount in child account
    txExecutor("hybrid-custody/setup_owned_account.cdc", [child], [nil, nil, nil], nil)
    // Publish ChildAccount for parent, factory & filter found in previously configured dev accoun
    txExecutor("hybrid-custody/publish_to_parent.cdc", [child], [parent.address, dev.address, dev.address], nil)
    // Redeem ChildAccount as parent
    txExecutor("hybrid-custody/redeem_account.cdc", [parent], [child.address, nil, nil], nil)

    // Configure NFT Collection in child account
    setupNFTCollection(child)
    // ExampleNFT Provider is allowed by Allowlist Filter, so should return valid Capability
    let returnsValidCap = scriptExecutor("test/get_nft_provider_capability_optional.cdc", [parent.address, child.address, false])! as! Bool
    Test.assertEqual(true, returnsValidCap)
    // Remove types from filter
    removeAllFilterTypes(dev, FilterKindAllowList)

    // ExampleNFT Provider has been removed from Allowlist Filter - getCapability() should return nil
    let returnsNil = scriptExecutor("test/get_nft_provider_capability_optional.cdc", [parent.address, child.address, true])! as! Bool
    Test.assertEqual(true, returnsNil)
}

access(all)
fun testChildAccount_getPublicCapability() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)

    scriptExecutor("hybrid-custody/get_nft_collection_public_capability.cdc", [parent.address, child.address])
}

access(all)
fun testCreateManagerWithInvalidFilterFails() {
    let parent = Test.createAccount()

    expectScriptFailure(
        "test/create_manager_with_invalid_filter.cdc",
        [parent.address],
        "Invalid CapabilityFilter Filter capability provided"
    )
}

access(all)
fun testCheckParentRedeemedStatus() {
    let child = Test.createAccount()
    let parent = Test.createAccount()
    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    setupOwnedAccount(child, FilterKindAll)

    setupAccountManager(parent)
    Test.assert(!isParent(child: child, parent: parent), message: "parent is already pending")

    txExecutor("hybrid-custody/publish_to_parent.cdc", [child], [parent.address, factory.address, filter.address], nil)
    Test.assert(isParent(child: child, parent: parent), message: "parent is already pending")

    txExecutor("hybrid-custody/redeem_account.cdc", [parent], [child.address, nil, nil], nil)
    Test.assert(checkIsRedeemed(child: child, parent: parent), message: "parents was redeemed but is not marked properly")
}

access(all)
fun testSeal() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let numKeysBefore = getNumValidKeys(child)
    Test.assert(numKeysBefore > 0, message: "no keys to revoke")

    // Get the controller ID for the current Account capability
    let controllerID = getAccountCapControllerID(account: child)
        ?? panic("controller ID should not be nil")

    let owner = getOwner(child: child)
    Test.assert(owner! == child.address, message: "mismatched owner")

    txExecutor("hybrid-custody/relinquish_ownership.cdc", [child], [], nil)
    let numKeysAfter = getNumValidKeys(child)
    Test.assert(numKeysAfter == 0, message: "not all keys were revoked")
    let newControllerID = getAccountCapControllerID(account: child)
        ?? panic("new controller ID should not be nil")
    Test.assert(newControllerID != controllerID, message: "Found Auth Account Capability at default path")
    let ownerAfter = getOwner(child: child)
    Test.assert(ownerAfter == nil, message: "should not have an owner anymore")
}

access(all)
fun testTransferOwnership() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let owner = Test.createAccount()
    setupAccountManager(owner)

    Test.assert(
        !(scriptExecutor("hybrid-custody/has_owned_accounts.cdc", [owner.address]) as! Bool?)!,
        message: "owner should not have owned accounts before transfer"
    )

    txExecutor("hybrid-custody/transfer_ownership.cdc", [child], [owner.address], nil)
    Test.assert(getPendingOwner(child: child)! == owner.address, message: "child account pending ownership was not updated correctly")

    txExecutor("hybrid-custody/accept_ownership.cdc", [owner], [child.address, nil, nil], nil)
    Test.assert(getOwner(child: child)! == owner.address, message: "child account ownership is not correct")
    Test.assert(getPendingOwner(child: child) == nil, message: "pending owner was not cleared after claiming ownership")

    Test.assert(
        (scriptExecutor("hybrid-custody/has_owned_accounts.cdc", [owner.address]) as! Bool?)!,
        message: "parent should have owned accounts after transfer"
    )
}

access(all)
fun testTransferOwnershipFromManager() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let owner = Test.createAccount()
    setupAccountManager(owner)

    Test.assert(
        !(scriptExecutor("hybrid-custody/has_owned_accounts.cdc", [owner.address]) as! Bool?)!,
        message: "owner should not have owned accounts before transfer"
    )

    txExecutor("hybrid-custody/transfer_ownership.cdc", [child], [owner.address], nil)
    Test.assert(getPendingOwner(child: child)! == owner.address, message: "child account pending ownership was not updated correctly")

    txExecutor("hybrid-custody/accept_ownership.cdc", [owner], [child.address, nil, nil], nil)
    Test.assert(getOwner(child: child)! == owner.address, message: "child account ownership is not correct")
    Test.assert(getPendingOwner(child: child) == nil, message: "pending owner was not cleared after claiming ownership")

    Test.assert(
        (scriptExecutor("hybrid-custody/has_owned_accounts.cdc", [owner.address]) as! Bool?)!,
        message: "parent should have owned accounts after transfer"
    )

    let newOwner = Test.createAccount()
    setupAccountManager(newOwner)

    Test.assert(
        !(scriptExecutor("hybrid-custody/has_owned_accounts.cdc", [newOwner.address]) as! Bool?)!,
        message: "owner should not have owned accounts before transfer"
    )

    txExecutor("hybrid-custody/transfer_ownership_from_manager.cdc", [owner], [child.address, newOwner.address], nil)
    Test.assert(getPendingOwner(child: child)! == newOwner.address, message: "child account pending ownership was not updated correctly")

    txExecutor("hybrid-custody/accept_ownership.cdc", [newOwner], [child.address, nil, nil], nil)
    Test.assert(getOwner(child: child)! == newOwner.address, message: "child account ownership is not correct")
    Test.assert(getPendingOwner(child: child) == nil, message: "pending owner was not cleared after claiming ownership")
}

access(all)
fun testGetCapability_ManagerFilterAllowed() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)

    scriptExecutor("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child.address])

    let filter = getTestAccount(FilterKindAllowList)
    setupFilter(filter, FilterKindAllowList)

    let nftIdentifier = buildTypeIdentifier(getTestAccount(exampleNFT), exampleNFT, "Collection")
    setManagerFilterOnChild(child: child, parent: parent, filterAddress: filter.address)

    expectScriptFailure(
        "hybrid-custody/get_nft_provider_capability.cdc",
        [parent.address, child.address],
        "capability not found"
    )

    addTypeToFilter(filter, FilterKindAllowList, nftIdentifier)
    scriptExecutor("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child.address])
}

access(all)
fun testAllowlistFilterRemoveAllTypes() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)

    scriptExecutor("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child.address])

    let filter = getTestAccount(FilterKindAllowList)
    setupFilter(filter, FilterKindAllowList)

    let nftIdentifier = buildTypeIdentifier(getTestAccount(exampleNFT), exampleNFT, "Collection")
    setManagerFilterOnChild(child: child, parent: parent, filterAddress: filter.address)

    addTypeToFilter(filter, FilterKindAllowList, nftIdentifier)

    scriptExecutor("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child.address])

    removeAllFilterTypes(filter, FilterKindAllowList)

    expectScriptFailure(
        "hybrid-custody/get_nft_provider_capability.cdc",
        [parent.address, child.address],
        "capability not found"
    )
}

access(all)
fun testDenyListFilterRemoveAllTypes() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)

    scriptExecutor("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child.address])

    let filter = getTestAccount(FilterKindDenyList)
    setupFilter(filter, FilterKindDenyList)

    let nftIdentifier = buildTypeIdentifier(getTestAccount(exampleNFT), exampleNFT, "Collection")
    addTypeToFilter(filter, FilterKindDenyList, nftIdentifier)
    setManagerFilterOnChild(child: child, parent: parent, filterAddress: filter.address)

    expectScriptFailure(
        "hybrid-custody/get_nft_provider_capability.cdc",
        [parent.address, child.address],
        "capability not found"
    )


    removeAllFilterTypes(filter, FilterKindDenyList)
    scriptExecutor("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child.address])
}

access(all)
fun testGetCapability_ManagerFilterNotAllowed() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)

    scriptExecutor("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child.address])

    let filter = getTestAccount(FilterKindDenyList)
    setupFilter(filter, FilterKindDenyList)

    let nftIdentifier = buildTypeIdentifier(getTestAccount(exampleNFT), exampleNFT, "Collection")
    addTypeToFilter(filter, FilterKindDenyList, nftIdentifier)
    setManagerFilterOnChild(child: child, parent: parent, filterAddress: filter.address)

    expectScriptFailure(
        "hybrid-custody/get_nft_provider_capability.cdc",
        [parent.address, child.address],
        "capability not found"
    )
}

access(all)
fun testGetPrivateCapabilityFromDelegator() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let isPublic = false
    setupNFTCollection(child)
    addNFTCollectionToDelegator(child: child, parent: parent, isPublic: isPublic)

    scriptExecutor("hybrid-custody/get_examplenft_collection_from_delegator.cdc", [parent.address, child.address, isPublic])
}

access(all)
fun testGetPublicCapabilityFromChild() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let isPublic = true
    setupNFTCollection(child)
    addNFTCollectionToDelegator(child: child, parent: parent, isPublic: isPublic)

    scriptExecutor("hybrid-custody/get_examplenft_collection_from_delegator.cdc", [parent.address, child.address, isPublic])
}

access(all)
fun testMetadata_ChildAccount_Metadata() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let name = "my name"
    let desc = "lorem ipsum"
    let url = "http://example.com/image.png"
    txExecutor("hybrid-custody/metadata/set_child_account_display.cdc", [parent], [child.address, name, desc, url], nil)

    let resolvedName = scriptExecutor("hybrid-custody/metadata/resolve_child_display_name.cdc", [parent.address, child.address])! as! String
    Test.assert(name == resolvedName, message: "names do not match")

    // set it again to make sure overrides work
    let name2 = "another name"
    txExecutor("hybrid-custody/metadata/set_child_account_display.cdc", [parent], [child.address, name2, desc, url], nil)
    let resolvedName2 = scriptExecutor("hybrid-custody/metadata/resolve_child_display_name.cdc", [parent.address, child.address])! as! String
    Test.assert(name2 == resolvedName2, message: "names do not match")
}

access(all)
fun testMetadata_OwnedAccount_Metadata() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let name = "my name"
    let desc = "lorem ipsum"
    let url = "http://example.com/image.png"
    txExecutor("hybrid-custody/metadata/set_owned_account_display.cdc", [child], [name, desc, url], nil)

    let resolvedName = scriptExecutor("hybrid-custody/metadata/resolve_owned_display_name.cdc", [child.address])! as! String
    Test.assert(name == resolvedName, message: "names do not match")

    // set it again to make sure overrides work
    let name2 = "another name"
    txExecutor("hybrid-custody/metadata/set_owned_account_display.cdc", [child], [name2, desc, url], nil)
    let resolvedName2 = scriptExecutor("hybrid-custody/metadata/resolve_owned_display_name.cdc", [child.address])! as! String
    Test.assert(name2 == resolvedName2, message: "names do not match")
}

access(all)
fun testGetChildAddresses() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)
    checkForAddresses(child: child, parent: parent)
}

access(all)
fun testRemoveChildAccount() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)
    checkForAddresses(child: child, parent: parent)


    Test.assert(isParent(child: child, parent: parent) == true, message: "is not parent of child account")
    txExecutor("hybrid-custody/remove_child_account.cdc", [parent], [child.address], nil)
    Test.assert(isParent(child: child, parent: parent) == false, message: "child account was not removed from parent")
}

access(all)
fun testGetAllFlowBalances() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let expectedChildBal = (scriptExecutor("test/get_flow_balance.cdc", [child.address]) as! UFix64?)!
    let expectedParentBal = (scriptExecutor("test/get_flow_balance.cdc", [parent.address]) as! UFix64?)!

    let result = (scriptExecutor("hybrid-custody/get_all_flow_balances.cdc", [parent.address]) as! {Address: UFix64}?)!

    Test.assert(
        result.containsKey(child.address) && result[child.address] == expectedChildBal,
        message: "child Flow balance incorrectly reported"
    )

    Test.assert(
        result.containsKey(parent.address) && result[parent.address] == expectedParentBal,
        message: "parent Flow balance incorrectly reported"
    )
}

access(all)
fun testGetAllFTBalance() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let expectedChildBal = (scriptExecutor("test/get_flow_balance.cdc", [child.address]) as! UFix64?)!
    let expectedParentBal = (scriptExecutor("test/get_flow_balance.cdc", [parent.address]) as! UFix64?)!

    let result = (scriptExecutor("test/get_all_vault_bal_from_storage.cdc", [parent.address]) as! {Address: {String: UFix64}}?)!

    Test.assert(
        result.containsKey(child.address) && result[child.address]!["A.0000000000000003.FlowToken.Vault"] == expectedChildBal,
        message: "child Flow balance incorrectly reported"
    )

    Test.assert(
        result.containsKey(parent.address) && result[parent.address]!["A.0000000000000003.FlowToken.Vault"] == expectedParentBal,
        message: "parent Flow balance incorrectly reported"
    )
}

access(all)
fun testGetFlowBalanceByStoragePath() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let expectedChildBal = (scriptExecutor("test/get_flow_balance.cdc", [child.address]) as! UFix64?)!
    let expectedParentBal = (scriptExecutor("test/get_flow_balance.cdc", [parent.address]) as! UFix64?)!

    let result = (scriptExecutor(
            "hybrid-custody/get_spec_balance_from_public.cdc",
            [parent.address, PublicPath(identifier: "flowTokenVault")!]
        ) as! {Address: UFix64}?)!

    Test.assert(
        result.containsKey(child.address) && result[child.address] == expectedChildBal,
        message: "child Flow balance incorrectly reported"
    )
    Test.assert(
        result.containsKey(parent.address) && result[parent.address] == expectedParentBal,
        message: "parent Flow balance incorrectly reported"
    )
}

access(all)
fun testGetNFTDisplayViewFromStorage() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

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
        "test/test_get_nft_display_view_from_storage.cdc",
        [parent.address, StoragePath(identifier: exampleNFTPublicIdentifier)!, expectedAddressToIDs]
    )
}

access(all)
fun testGetAllCollectionViewsFromStorage() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

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

access(all)
fun testSetupChildAndParentMultiSig() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    setupFilter(filter, FilterKindAll)
    setupFactoryManager(factory)

    txExecutor("hybrid-custody/setup_multi_sig.cdc", [child, parent], [filter.address, factory.address, filter.address], nil)

    Test.assert(isParent(child: child, parent: parent), message: "parent account not found")
}

access(all)
fun testSendChildFtsWithParentSigner() {
    let parent = Test.createAccount()
    let child = Test.createAccount()
    let child2 = Test.createAccount()
    let exampleToken = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let mintAmount: UFix64 = 100.0
    let amount: UFix64 = 10.0
    setupFT(child2)
    setupFT(child)
    setupFTProvider(child)

    txExecutor("example-token/mint_tokens.cdc", [exampleToken], [child.address, mintAmount], nil)
    let balance: UFix64? = getBalance(child)
    Test.assert(balance == mintAmount, message: "balance should be".concat(mintAmount.toString()))

    let recipientBalanceBefore: UFix64? = getBalance(child2)
    Test.assert(recipientBalanceBefore == 0.0, message: "recipient balance should be 0")

    txExecutor("hybrid-custody/send_child_ft_with_parent.cdc", [parent], [amount, child2.address, child.address], nil)

    let recipientBalanceAfter: UFix64? = getBalance(child2)
    Test.assert(recipientBalanceAfter == amount, message: "recipient balance should be".concat(amount.toString()))
}

access(all)
fun testSendChildNFTsWithParentSigner() {
    let parent = Test.createAccount()
    let child = Test.createAccount()
    let recipient = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let mintAmount: UFix64 = 100.0
    let amount: UFix64 = 10.0
    setupNFTCollection(child)
    setupNFTCollection(recipient)

    mintNFTDefault(accounts[exampleNFT]!, receiver: child)
    mintNFTDefault(accounts[exampleNFT]!, receiver: child)

    let childIDs = (scriptExecutor("example-nft/get_ids.cdc", [child.address]) as! [UInt64]?)!
    Test.assert(childIDs.length == 2, message: "no NFTs found in child account after minting")

    let recipientIDs = (scriptExecutor("example-nft/get_ids.cdc", [recipient.address]) as! [UInt64]?)!
    Test.assert(recipientIDs.length == 0, message: "NFTs found in recipient account without minting")

    txExecutor("hybrid-custody/send_child_nfts_with_parent.cdc", [parent], [childIDs, recipient.address, child.address], nil)

    let childIDsAfter = (scriptExecutor("example-nft/get_ids.cdc", [child.address]) as! [UInt64]?)!
    Test.assert(childIDsAfter.length == 0, message: "NFTs found in child account after transfer - collection should be empty")

    let recipientIDsAfter = (scriptExecutor("example-nft/get_ids.cdc", [recipient.address]) as! [UInt64]?)!
    Test.assert(recipientIDsAfter.length == 2, message: "recipient should have received 2 NFTs from child")
}

access(all)
fun testAddExampleTokenToBalance() {
    let child = Test.createAccount()
    let exampleToken = Test.createAccount()

    setupFT(child)

    let amount: UFix64 = 100.0
    txExecutor("example-token/mint_tokens.cdc", [exampleToken], [child.address, amount], nil)

    let balance: UFix64? = getBalance(child)
    Test.assert(balance == amount, message: "balance should be".concat(amount.toString()))
}

access(all)
fun testSetupOwnedAccountWithDisplay() {
    let acct = Test.createAccount()

    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    setupFilter(filter, FilterKindAll)
    setupFactoryManager(factory)

    let name = "my name"
    let desc = "description"
    let thumbnail = "https://example.com/test.jpeg"

    txExecutor("hybrid-custody/setup_owned_account.cdc", [acct], [name, desc, thumbnail], nil)
    Test.assert(scriptExecutor("hybrid-custody/metadata/assert_owned_account_display.cdc", [acct.address, name, desc, thumbnail])! as! Bool, message: "failed to match display")
}

access(all)
fun testGetChildAccountNFTCapabilities(){
    let child = Test.createAccount()
    let parent = Test.createAccount()
    let nftIdentifier = buildTypeIdentifier(getTestAccount(exampleNFT), exampleNFT, "Collection")
    let nftIdentifier2 = buildTypeIdentifier(getTestAccount(exampleNFT2), exampleNFT2, "Collection")

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let isPublic = true
    setupNFT2Collection(child)
    setupNFTCollection(child)

    addNFTCollectionToDelegator(child: child, parent: parent, isPublic: isPublic)
    addNFT2CollectionToDelegator(child: child, parent: parent, isPublic: isPublic)

    let nftTypeIds = scriptExecutor("hybrid-custody/get_child_account_nft_capabilities.cdc", [parent.address])! as! {Address: [String]}
    Test.assert(
        nftTypeIds.containsKey(child.address) && nftTypeIds[child.address]!.contains(nftIdentifier),
        message: "typeId should be: ".concat(nftIdentifier)
    )
    Test.assert(
        nftTypeIds.containsKey(child.address) && nftTypeIds[child.address]!.contains(nftIdentifier2),
        message: "typeId should be: ".concat(nftIdentifier2)
    )
}

access(all)
fun testGetNFTsAccessibleFromChildAccount(){
    let child = Test.createAccount()
    let parent = Test.createAccount()
    let nftIdentifier = buildTypeIdentifier(getTestAccount(exampleNFT), exampleNFT, "Collection")
    let nftIdentifier2 = buildTypeIdentifier(getTestAccount(exampleNFT2), exampleNFT2, "Collection")

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)
    setupNFT2Collection(child)

    setupNFTCollection(parent)
    setupNFT2Collection(parent)

    mintNFTDefault(accounts[exampleNFT]!, receiver: child)

    let expectedChildIDs = (scriptExecutor("example-nft/get_ids.cdc", [child.address]) as! [UInt64]?)!
    let expectedParentIDs: [UInt64] = []
    let expectedAddressToIDs: {Address: [UInt64]} = {child.address: expectedChildIDs, parent.address: expectedParentIDs}

    scriptExecutor(
        "test/test_get_nft_display_view_from_storage.cdc",
        [parent.address, StoragePath(identifier: exampleNFTPublicIdentifier)!, expectedAddressToIDs]
    )

    // Test we have capabilities to access the minted NFTs
    scriptExecutor("test/test_get_accessible_child_nfts.cdc", [
        parent.address,
        {child.address: expectedChildIDs}
    ])

    // // Mint new nfts from ExampleNFT2 and assert that get_accessible_child_nfts.cdc does not return these nfts.
    mintExampleNFT2Default(accounts[exampleNFT2]!, receiver: child)
    let expectedChildIDs2 = (scriptExecutor("example-nft-2/get_ids.cdc", [child.address]) as! [UInt64]?)!
    let expectedAddressToIDs2: {Address: [UInt64]} = {child.address: expectedChildIDs2, parent.address: expectedParentIDs}

    scriptExecutor(
        "test/test_get_nft_display_view_from_storage.cdc",
        [parent.address, StoragePath(identifier: exampleNFT2PublicIdentifier)!, expectedAddressToIDs2]
    )

    // revoke the ExampleNFT2 provider capability, preventing it from being returned.
    let paths: [StoragePath] = [
        /storage/exampleNFT2Collection,
        /storage/exampleNFTCollection
    ]
    txExecutor("misc/unlink_from_storage_paths.cdc", [child], [paths], nil)

    let expectedAddressToIDsFails: {Address: [UInt64]} = {child.address: expectedChildIDs2}
    expectScriptFailure(
        "test/test_get_accessible_child_nfts.cdc",
        [parent.address, expectedAddressToIDsFails],
        "Resulting ID does not match expected ID!"
    )
}

access(all)
fun testGetChildAccountFTCapabilities(){
    let child = Test.createAccount()
    let parent = Test.createAccount()
    let nftIdentifier = buildTypeIdentifier(getTestAccount(exampleToken), exampleToken, "Vault")

    setupChildAndParent_FilterKindAll(child: child, parent: parent)
    setupFTProvider(child)

    let ftTypeIds = scriptExecutor("hybrid-custody/get_child_account_ft_capabilities.cdc", [parent.address])! as! {Address: [String]}
    Test.assert(ftTypeIds[child.address]![0] == nftIdentifier, message: "typeId should be: ".concat(nftIdentifier))
}

access(all)
fun testBlockchainNativeOnboarding() {
    let filter = getTestAccount(FilterKindAll)
    let factory = getTestAccount(nftFactory)

    setupFilter(filter, FilterKindAll)
    setupFactoryManager(factory)

    let app = Test.createAccount()
    let parent = Test.createAccount()

    let pubKeyStr = "1290b0382db250ffb4c2992039b1c9ed3b60e15afd4181ee0e0b9d5263e3a8aef4e91b1214f7baa44e30a31a1ce83489d37d5b0af64d848f4e2ce4e89818059e"
    let expectedPubKey = PublicKey(
            publicKey: pubKeyStr.decodeHex(),
            signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
        )

    txExecutor("hybrid-custody/onboarding/blockchain_native.cdc", [parent, app], [pubKeyStr, 0.0, factory.address, filter.address], nil)

    let childAddresses = scriptExecutor("hybrid-custody/get_child_addresses.cdc", [parent.address]) as! [Address]?
        ?? panic("problem adding blockchain native child account to signing parent")
    let child = Test.TestAccount(address: childAddresses[0], publicKey: expectedPubKey)

    Test.assert(checkForAddresses(child: child, parent: parent), message: "child account not linked to parent")
}

access(all)
fun testSetDefaultManagerFilter() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)
    setupNFTCollection(child)

    scriptExecutor("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child.address])

    let filter = getTestAccount(FilterKindDenyList)
    setupFilter(filter, FilterKindDenyList)

    txExecutor("hybrid-custody/set_default_manager_cap.cdc", [parent], [filter.address], nil)

    let child2 = Test.createAccount()
    setupChildAndParent_FilterKindAll(child: child2, parent: parent)
    setupNFTCollection(child2)

    let nftIdentifier = buildTypeIdentifier(getTestAccount(exampleNFT), exampleNFT, "Collection")
    addTypeToFilter(filter, FilterKindDenyList, nftIdentifier)

    expectScriptFailure(
        "hybrid-custody/get_nft_provider_capability.cdc",
        [parent.address, child2.address],
        "capability not found"
    )
}

access(all)
fun testPublishToParent_alreadyExists() {
    let tmp = Test.createAccount()
    setupOwnedAccount(tmp, FilterKindAll)

    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    let parent = Test.createAccount()

    // put a resource in the ChildAccount storage slot for the parent to guarantee that publishing will not work
    txExecutor("hybrid-custody/misc/save_resource_to_parent_child_storage_slot.cdc", [tmp], [parent.address], nil)

    // this should fail because something is already stored where the child account is located
    txExecutor(
        "hybrid-custody/publish_to_parent.cdc",
        [tmp],
        [parent.address, factory.address, filter.address],
        "conflicting resource found in child account storage slot for parentAddress"
    )
}

access(all)
fun testRemoveParent() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    // remove the parent and validate the the parent manager resource doesn't have the child anymore
    txExecutor("hybrid-custody/remove_parent_from_child.cdc", [child], [parent.address], nil)
}

access(all)
fun testGetChildAccountCapabilityFilterAndFactory() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)
    scriptExecutor("test/can_get_child_factory_and_filter_caps.cdc", [child.address, parent.address])
}

access(all)
fun testSetCapabilityFactoryForParent() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let newFactory = Test.createAccount()
    setupEmptyFactory(newFactory)

    txExecutor("hybrid-custody/set_capability_factory_for_parent.cdc", [child], [parent.address, newFactory.address], nil)

    expectScriptFailure(
        "hybrid-custody/get_nft_provider_capability.cdc",
        [parent.address, child.address],
        "capability not found"
    )
}

access(all)
fun testSetCapabilityFilterForParent() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let newFilter = Test.createAccount()
    setupFilter(newFilter, FilterKindAllowList)

    txExecutor("hybrid-custody/set_capability_filter_for_parent.cdc", [child], [parent.address, newFilter.address], nil)

    expectScriptFailure(
        "hybrid-custody/get_nft_provider_capability.cdc",
        [parent.address, child.address],
        "capability not found"
    )
}

access(all)
fun testSetChildAccountDisplay_toNil() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)
    txExecutor("hybrid-custody/metadata/set_child_account_display_to_nil.cdc", [parent], [child.address], nil)

    expectScriptFailure(
        "hybrid-custody/metadata/resolve_child_display_name.cdc",
        [parent.address, child.address],
        "unable to resolve metadata display"
    )
}

access(all)
fun testRemoveChild_invalidChildAccountCapability() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    txExecutor("hybrid-custody/unlink_child_capability.cdc", [child], [parent.address], nil)

    txExecutor("hybrid-custody/remove_child_account.cdc", [parent], [child.address], nil)

    let e = Test.eventsOfType(Type<HybridCustody.AccountUpdated>()).removeLast() as! HybridCustody.AccountUpdated
    Test.assert(e.child == child.address, message: "unexpected AccountUpdated value")
}

access(all)
fun testBorrowAccount_nilCapability() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)
    txExecutor("hybrid-custody/unlink_child_capability.cdc", [child], [parent.address], nil)

    expectScriptFailure(
        "hybrid-custody/metadata/resolve_child_display_name.cdc",
        [parent.address, child.address],
        "child not found"
    )    
}

access(all)
fun testBorrowAccountPublic() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let res = scriptExecutor("hybrid-custody/get_account_public_address.cdc", [parent.address, child.address])! as! Address
    Test.assertEqual(child.address, res)

    txExecutor("hybrid-custody/remove_child_account.cdc", [parent], [child.address], nil)

    expectScriptFailure("hybrid-custody/get_account_public_address.cdc", [parent.address, child.address], "child account not found")
}

access(all) fun testBorrowOwnedAccount() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let owner = Test.createAccount()
    setupAccountManager(owner)

    txExecutor("hybrid-custody/transfer_ownership.cdc", [child], [owner.address], nil)
    Test.assert(getPendingOwner(child: child)! == owner.address, message: "child account pending ownership was not updated correctly")

    txExecutor("hybrid-custody/accept_ownership.cdc", [owner], [child.address, nil, nil], nil)

    let res = scriptExecutor("hybrid-custody/borrow_owned_account.cdc", [owner.address, child.address])! as! Address
    Test.assertEqual(child.address, res)

    expectScriptFailure("hybrid-custody/borrow_owned_account.cdc", [owner.address, parent.address], "could not borrow owned account")
}

access(all)
fun testRemoveOwned() {
    let child = Test.createAccount()
    let owner = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: Test.createAccount())
    setupAccountManager(owner)

    txExecutor("hybrid-custody/transfer_ownership.cdc", [child], [owner.address], nil)
    Test.assert(getPendingOwner(child: child)! == owner.address, message: "child account pending ownership was not updated correctly")

    txExecutor("hybrid-custody/accept_ownership.cdc", [owner], [child.address, nil, nil], nil)

    // remove the owned account
    txExecutor("hybrid-custody/remove_owned_account.cdc", [owner], [child.address], nil)

    let sealEvent = Test.eventsOfType(Type<HybridCustody.AccountSealed>()).removeLast() as! HybridCustody.AccountSealed
    Test.assertEqual(child.address, sealEvent.address)

    let ownershipEvent = Test.eventsOfType(Type<HybridCustody.OwnershipUpdated>()).removeLast() as! HybridCustody.OwnershipUpdated
    Test.assertEqual(owner.address, ownershipEvent.previousOwner!)
    Test.assertEqual(nil, ownershipEvent.owner)
}

access(all)
fun testManager_burnCallback() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    txExecutor("hybrid-custody/destroy_manager.cdc", [parent], [], nil)

    let e = Test.eventsOfType(Type<HybridCustody.AccountUpdated>()).removeLast() as! HybridCustody.AccountUpdated
    Test.assertEqual(e.child, child.address)
}

access(all)
fun testChildAccount_burnCallback() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let beforeChildren = (scriptExecutor("hybrid-custody/get_child_addresses.cdc", [parent.address]))! as! [Address]
    Test.assert(beforeChildren.contains(child.address), message: "missing child address")

    txExecutor("hybrid-custody/destroy_child.cdc", [child], [parent.address], nil)

    let e = Test.eventsOfType(Type<HybridCustody.ChildAccount.ResourceDestroyed>()).removeLast() as! HybridCustody.ChildAccount.ResourceDestroyed
    Test.assertEqual(child.address, e.address)
    Test.assertEqual(parent.address, e.parent)

    // make sure that the parent no longer has the child account (burn callback should have removed it)
    let afterChildren: [Address] = (scriptExecutor("hybrid-custody/get_child_addresses.cdc", [parent.address]))! as! [Address]
    Test.assert(!afterChildren.contains(child.address), message: "child address found but should not have been")
}

access(all)
fun testOwnedAccount_burnCallback() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)
    txExecutor("hybrid-custody/destroy_owned_account.cdc", [child], [], nil)

    let children = (scriptExecutor("hybrid-custody/get_child_addresses.cdc", [parent.address]))! as! [Address]
    Test.assert(!children.contains(child.address), message: "child account found when it should not have been")
}

access(all)
fun testGetPublicCapability() {
    let child = Test.createAccount()
    let parent = Test.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)
    mintNFTDefault(accounts[exampleNFT]!, receiver: child)

    let ids = scriptExecutor(
        "hybrid-custody/get_collection_public_from_child.cdc",
        [parent.address, child.address, PublicPath(identifier: exampleNFTPublicIdentifier)!, Type<&{NonFungibleToken.CollectionPublic}>()]
    )! as! [UInt64]
    Test.assert(ids.length > 0, message: "unexpected number of nfts in collection")

    // now try with a type that doesn't have a factory configured for it
    Test.expectFailure(fun() {
        scriptExecutor(
            "hybrid-custody/get_collection_public_from_child.cdc",
            [parent.address, child.address, PublicPath(identifier: exampleNFTPublicIdentifier)!, Type<&ExampleNFT.Collection>()]
        )! as! [UInt64]
    }, errorMessageSubstring: "could not get capability")
}

// --------------- End Test Cases ---------------


// --------------- Transaction wrapper functions ---------------

access(all)
fun setupChildAndParent_FilterKindAll(child: Test.TestAccount, parent: Test.TestAccount) {
    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    setupOwnedAccount(child, FilterKindAll)

    setupAccountManager(parent)

    txExecutor("hybrid-custody/publish_to_parent.cdc", [child], [parent.address, factory.address, filter.address], nil)

    txExecutor("hybrid-custody/redeem_account.cdc", [parent], [child.address, nil, nil], nil)
}

access(all)
fun setupAccountManager(_ acct: Test.TestAccount) {
    txExecutor("hybrid-custody/setup_manager.cdc", [acct], [nil, nil], nil)
}

access(all)
fun setAccountManagerWithFilter(_ acct: Test.TestAccount, _ filterAccount: Test.TestAccount) {
    txExecutor("hybrid-custody/setup_manager.cdc", [acct], [nil, nil], nil)
}

access(all)
fun setManagerFilterOnChild(child: Test.TestAccount, parent: Test.TestAccount, filterAddress: Address) {
    txExecutor("hybrid-custody/set_manager_filter_cap.cdc", [parent], [filterAddress, child.address], nil)
}

access(all)
fun setupOwnedAccount(_ acct: Test.TestAccount, _ filterKind: String) {
    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(filterKind)

    setupFilter(filter, filterKind)
    setupFactoryManager(factory)

    setupNFTCollection(acct)
    setupFT(acct)


    txExecutor("hybrid-custody/setup_owned_account.cdc", [acct], [nil, nil, nil], nil)
}

access(all)
fun setupFactoryManager(_ acct: Test.TestAccount) {
    txExecutor("factory/setup_nft_ft_manager.cdc", [acct], [], nil)
}

access(all)
fun setupEmptyFactory(_ acct: Test.TestAccount) {
    txExecutor("factory/setup_empty_factory.cdc", [acct], [], nil)
}

access(all)
fun setupNFTCollection(_ acct: Test.TestAccount) {
    txExecutor("example-nft/setup_full.cdc", [acct], [], nil)
}

access(all)
fun setupNFT2Collection(_ acct: Test.TestAccount) {
    txExecutor("example-nft-2/setup_full.cdc", [acct], [], nil)
}

access(all)
fun mintNFT(_ minter: Test.TestAccount, receiver: Test.TestAccount, name: String, description: String, thumbnail: String) {
    let filepath: String = "example-nft/mint_to_account.cdc"
    txExecutor(filepath, [minter], [receiver.address, name, description, thumbnail], nil)
}

access(all)
fun mintNFTDefault(_ minter: Test.TestAccount, receiver: Test.TestAccount) {
    return mintNFT(minter, receiver: receiver, name: "example nft", description: "lorem ipsum", thumbnail: "http://example.com/image.png")
}

access(all)
fun mintExampleNFT2(_ minter: Test.TestAccount, receiver: Test.TestAccount, name: String, description: String, thumbnail: String) {
    let filepath: String = "example-nft-2/mint_to_account.cdc"
    txExecutor(filepath, [minter], [receiver.address, name, description, thumbnail], nil)
}

access(all)
fun mintExampleNFT2Default(_ minter: Test.TestAccount, receiver: Test.TestAccount) {
    return mintExampleNFT2(minter, receiver: receiver, name: "example nft 2", description: "lorem ipsum", thumbnail: "http://example.com/image.png")
}

access(all)
fun setupFT(_ acct: Test.TestAccount) {
    txExecutor("example-token/setup.cdc", [acct], [], nil)
}

access(all)
fun setupFTProvider(_ acct: Test.TestAccount) {
    txExecutor("example-token/setup_provider.cdc", [acct], [], nil)
}

access(all)
fun setupFilter(_ acct: Test.TestAccount, _ kind: String) {
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
            Test.assert(false, message: "unknown filter kind given")
    }

    txExecutor(filePath, [acct], [], nil)
}

access(all)
fun addTypeToFilter(_ acct: Test.TestAccount, _ kind: String, _ identifier: String) {
    var filePath = ""
    switch kind {
        case FilterKindAllowList:
            filePath = "filter/allow/add_type_to_list.cdc"
            break
        case FilterKindDenyList:
            filePath = "filter/deny/add_type_to_list.cdc"
            break
        default:
            Test.assert(false, message: "unknown filter kind given")
    }

    txExecutor(filePath, [acct], [identifier], nil)
}

access(all)
fun removeAllFilterTypes(_ acct: Test.TestAccount, _ kind: String) {
    var filePath = ""
    switch kind {
        case FilterKindAllowList:
            filePath = "filter/allow/remove_all_types.cdc"
            break
        case FilterKindDenyList:
            filePath = "filter/deny/remove_all_types.cdc"
            break
        default:
            Test.assert(false, message: "unknown filter kind given")
    }

    txExecutor(filePath, [acct], [], nil)
}

access(all)
fun addNFTCollectionToDelegator(child: Test.TestAccount, parent: Test.TestAccount, isPublic: Bool) {
    txExecutor("hybrid-custody/add_example_nft_collection_to_delegator.cdc", [child], [parent.address, isPublic], nil)
}

access(all)
fun addNFT2CollectionToDelegator(child: Test.TestAccount, parent: Test.TestAccount, isPublic: Bool) {
    txExecutor("hybrid-custody/add_example_nft2_collection_to_delegator.cdc", [child], [parent.address, isPublic], nil)
}
// ---------------- End Transaction wrapper functions

// ---------------- Begin script wrapper functions

access(all)
fun getParentStatusesForChild(_ child: Test.TestAccount): {Address: Bool} {
    return scriptExecutor("hybrid-custody/get_parents_from_child.cdc", [child.address])! as! {Address: Bool}
}

access(all)
fun isParent(child: Test.TestAccount, parent: Test.TestAccount): Bool {
    return scriptExecutor("hybrid-custody/is_parent.cdc", [child.address, parent.address])! as! Bool
}

access(all)
fun checkIsRedeemed(child: Test.TestAccount, parent: Test.TestAccount): Bool {
    return scriptExecutor("hybrid-custody/is_redeemed.cdc", [child.address, parent.address])! as! Bool
}

access(all)
fun getNumValidKeys(_ child: Test.TestAccount): Int {
    return scriptExecutor("hybrid-custody/get_num_valid_keys.cdc", [child.address])! as! Int
}

access(all)
fun getAccountCapControllerID(account: Test.TestAccount): UInt64? {
    return scriptExecutor("hybrid-custody/get_account_cap_con_id.cdc", [account.address]) as! UInt64?
}

access(all)
fun getOwner(child: Test.TestAccount): Address? {
    let res = scriptExecutor("hybrid-custody/get_owner_of_child.cdc", [child.address])
    if res == nil {
        return nil
    }

    return res! as! Address
}

access(all)
fun getPendingOwner(child: Test.TestAccount): Address? {
    let res = scriptExecutor("hybrid-custody/get_pending_owner_of_child.cdc", [child.address])

    return res as! Address?
}

access(all)
fun checkForAddresses(child: Test.TestAccount, parent: Test.TestAccount): Bool {
    let childAddressResult: [Address]? = (scriptExecutor("hybrid-custody/get_child_addresses.cdc", [parent.address])) as! [Address]?
    Test.assert(childAddressResult?.contains(child.address) == true, message: "child address not found")

    let parentAddressResult: [Address]? = (scriptExecutor("hybrid-custody/get_parent_addresses.cdc", [child.address])) as! [Address]?
    Test.assert(parentAddressResult?.contains(parent.address) == true, message: "parent address not found")
    return true
}

access(all)
fun getBalance(_ acct: Test.TestAccount): UFix64 {
    let balance: UFix64? = (scriptExecutor("example-token/get_balance.cdc", [acct.address])! as! UFix64)
    return balance!
}

// ---------------- End script wrapper functions

// ---------------- BEGIN General-purpose helper functions

access(all)
fun buildTypeIdentifier(_ acct: Test.TestAccount, _ contractName: String, _ suffix: String): String {
    let addrString = acct.address.toString()
    return "A.".concat(addrString.slice(from: 2, upTo: addrString.length)).concat(".").concat(contractName).concat(".").concat(suffix)
}

access(all)
fun getCapabilityFilterPath(): String {
    let filterAcct =  getTestAccount(capabilityFilter)

    return "CapabilityFilter".concat(filterAcct.address.toString())
}

// ---------------- END General-purpose helper functions

access(all)
fun getTestAccount(_ name: String): Test.TestAccount {
    if accounts[name] == nil {
        accounts[name] = Test.createAccount()
    }

    return accounts[name]!
}

access(all)
fun setup() {
    // actual test accounts
    let parent = Test.createAccount()
    let child1 = Test.createAccount()
    let child2 = Test.createAccount()

    accounts["HybridCustody"] = adminAccount
    accounts["CapabilityDelegator"] = adminAccount
    accounts["CapabilityFilter"] = adminAccount
    accounts["CapabilityFactory"] = adminAccount
    accounts["NFTCollectionPublicFactory"] = adminAccount
    accounts["NFTProviderAndCollectionFactory"] = adminAccount
    accounts["NFTProviderFactory"] = adminAccount
    accounts["NFTCollectionFactory"] = adminAccount
    accounts["FTProviderFactory"] = adminAccount
    accounts["FTBalanceFactory"] = adminAccount
    accounts["FTReceiverBalanceFactory"] = adminAccount
    accounts["FTReceiverFactory"] = adminAccount
    accounts["FTAllFactory"] = adminAccount
    accounts["FTVaultFactory"] = adminAccount
    accounts["ExampleNFT"] = adminAccount
    accounts["ExampleNFT2"] = adminAccount
    accounts["ExampleToken"] = adminAccount
    accounts["parent"] = parent
    accounts["child1"] = child1
    accounts["child2"] = child2
    accounts["nftCapFactory"] = adminAccount

    // helper nft contract so we can actually talk to nfts with tests
    deploy("ExampleNFT", "../contracts/standard/ExampleNFT.cdc")
    deploy("ExampleNFT2", "../contracts/standard/ExampleNFT2.cdc")
    deploy("ExampleToken", "../contracts/standard/ExampleToken.cdc")

    // our main contract is last
    deploy("CapabilityDelegator", "../contracts/CapabilityDelegator.cdc")
    deploy("CapabilityFilter", "../contracts/CapabilityFilter.cdc")
    deploy("CapabilityFactory", "../contracts/CapabilityFactory.cdc")
    deploy("NFTCollectionPublicFactory", "../contracts/factories/NFTCollectionPublicFactory.cdc")
    deploy("NFTProviderAndCollectionFactory", "../contracts/factories/NFTProviderAndCollectionFactory.cdc")
    deploy("NFTProviderFactory", "../contracts/factories/NFTProviderFactory.cdc")
    deploy("NFTCollectionFactory", "../contracts/factories/NFTCollectionFactory.cdc")
    deploy("FTProviderFactory", "../contracts/factories/FTProviderFactory.cdc")
    deploy("FTBalanceFactory", "../contracts/factories/FTBalanceFactory.cdc")
    deploy("FTReceiverBalanceFactory", "../contracts/factories/FTReceiverBalanceFactory.cdc")
    deploy("FTReceiverFactory", "../contracts/factories/FTReceiverFactory.cdc")
    deploy("FTAllFactory", "../contracts/factories/FTAllFactory.cdc")
    deploy("FTVaultFactory", "../contracts/factories/FTVaultFactory.cdc")
    deploy("HybridCustody", "../contracts/HybridCustody.cdc")
}
