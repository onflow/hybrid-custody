import Test

pub var accounts: {String: Test.Account} = {}
pub var blockchain = Test.newEmulatorBlockchain()
pub let fungibleTokenAddress: Address = 0xee82856bf20e2aa6

pub let app = "app"
pub let child = "child"
pub let nftFactory = "nftFactory"
pub let exampleNFT = "ExampleNFT"
pub let flowToken = "FlowToken"
pub let capabilityFilter = "CapabilityFilter"

pub let FilterKindAll = "all"
pub let FilterKindAllowList = "allowlist"
pub let FilterKindDenyList = "denylist"

pub let exampleNFTPublicIdentifier = "ExampleNFTCollection"


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

pub fun testSetupChildAccount() {
    let tmp = blockchain.createAccount()
    setupChildAccount(tmp, FilterKindAll)
}

pub fun testPublishAccount() {
    let tmp = blockchain.createAccount()
    setupChildAccount(tmp, FilterKindAll)

    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    let parent = blockchain.createAccount()

    txExecutor("hybrid-custody/publish_to_parent.cdc", [tmp], [parent.address, factory.address, filter.address], nil, nil)

    scriptExecutor("hybrid-custody/get_collection_from_inbox.cdc", [parent.address, tmp.address])
}

pub fun testRedeemAccount() {
    let child = blockchain.createAccount()
    setupChildAccount(child, FilterKindAll)

    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    let parent = blockchain.createAccount()

    txExecutor("hybrid-custody/publish_to_parent.cdc", [child], [parent.address, factory.address, filter.address], nil, nil)

    setupAccountManager(parent)
    txExecutor("hybrid-custody/redeem_account.cdc", [parent], [child.address, nil, nil], nil, nil)

    scriptExecutor("hybrid-custody/has_address_as_child.cdc", [parent.address, child.address])
}

pub fun testProxyAccount_getAddress() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    scriptExecutor("hybrid-custody/verify_proxy_address.cdc", [parent.address, child.address])
}

pub fun testProxyAccount_hasChildAccounts() {
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

pub fun testProxyAccount_getCapability() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)

    scriptExecutor("hybrid-custody/get_nft_provider_capability.cdc", [parent.address, child.address])
}

pub fun testProxyAccount_getPublicCapability() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)

    scriptExecutor("hybrid-custody/get_nft_collection_public_capability.cdc", [parent.address, child.address])
}

pub fun testCheckParentRedeemedStatus() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()
    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    setupChildAccount(child, FilterKindAll)

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
    assert(getOwner(child: child)! == owner.address, message: "child account ownership was not updated correctly")

    txExecutor("hybrid-custody/accept_ownership.cdc", [owner], [child.address, nil, nil], nil, nil)
    assert(getOwner(child: child)! == owner.address, message: "child account ownership is not correct")

    assert(
        (scriptExecutor("hybrid-custody/has_owned_accounts.cdc", [owner.address]) as! Bool?)!,
        message: "parent should have owned accounts after transfer"
    )
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

pub fun testGetPrivateCapabilityFromProxy() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let isPublic = false
    setupNFTCollection(child)
    addNFTCollectionToProxy(child: child, parent: parent, isPublic: isPublic)

    scriptExecutor("hybrid-custody/get_examplenft_collection_from_proxy.cdc", [parent.address, child.address, isPublic])
}

pub fun testGetPublicCapabilityFromProxy() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let isPublic = true
    setupNFTCollection(child)
    addNFTCollectionToProxy(child: child, parent: parent, isPublic: isPublic)

    scriptExecutor("hybrid-custody/get_examplenft_collection_from_proxy.cdc", [parent.address, child.address, isPublic])
}

pub fun testMetadata_ProxyAccount_Metadata() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let name = "my name"
    let desc = "lorem ipsum"
    let url = "http://example.com/image.png"
    txExecutor("hybrid-custody/metadata/set_proxy_account_display.cdc", [parent], [child.address, name, desc, url], nil, nil)

    let resolvedName = scriptExecutor("hybrid-custody/metadata/resolve_proxy_display_name.cdc", [parent.address, child.address])! as! String
    assert(name == resolvedName, message: "names do not match")
}

pub fun testMetadata_ChildAccount_Metadata() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    let name = "my name"
    let desc = "lorem ipsum"
    let url = "http://example.com/image.png"
    txExecutor("hybrid-custody/metadata/set_child_account_display.cdc", [child], [name, desc, url], nil, nil)

    let resolvedName = scriptExecutor("hybrid-custody/metadata/resolve_child_display_name.cdc", [child.address])! as! String
    assert(name == resolvedName, message: "names do not match")
}

pub fun testGetAddresses() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)
    checkforAddresses(child: child, parent: parent)
}

pub fun testRemoveChildAccount() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)
    checkforAddresses(child: child, parent: parent)


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

pub fun testGetSpecViewFromPublic() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)
    setupNFTCollection(parent)

    mintNFTDefault(accounts["ExampleNFT"]!, receiver: child)
    mintNFTDefault(accounts[exampleNFT]!, receiver: parent)

    let expectedChildIDs = (scriptExecutor("example-nft/get_ids.cdc", [child.address]) as! [UInt64]?)!
    let expectedParentIDs = (scriptExecutor("example-nft/get_ids.cdc", [parent.address]) as! [UInt64]?)!

    let expectedAddressLength: Int = 2
    let expectedViewsLength: Int = 1

    let result = (scriptExecutor(
        "hybrid-custody/get_nft_display_view_from_public.cdc",
        [parent.address, PublicPath(identifier: exampleNFTPublicIdentifier)!]
        ) as! {Address: {UInt64: AnyStruct}}?)!

    assert(
        result.length == expectedAddressLength && result.containsKey(child.address) && result.containsKey(parent.address),
        message: "invalid number of account views returned"
    )
    assert(
        result[child.address]!.length == expectedAddressLength && result[child.address]!.containsKey(expectedChildIDs[0]),
        message: "invalid child account views returned"
    )
    assert(
        result[parent.address]!.length == expectedAddressLength && result[parent.address]!.containsKey(expectedChildIDs[0]),
        message: "invalid parent account views returned"
    )
}

pub fun testGetAllCollectionViewsFromStorage() {
    let child = blockchain.createAccount()
    let parent = blockchain.createAccount()

    setupChildAndParent_FilterKindAll(child: child, parent: parent)

    setupNFTCollection(child)
    setupNFTCollection(parent)

    let expectedAddressLength: Int = 2
    let expectedViewsLength: Int = 1

    let result = (scriptExecutor(
        "hybrid-custody/get_all_collection_views_from_storage.cdc",
        [parent.address]
        ) as! {Address: [AnyStruct]}?)!

    assert(
        result.length == expectedAddressLength && result.containsKey(child.address) && result.containsKey(parent.address),
        message: "invalid number of account views returned"
    )
    assert(
        result[child.address]!.length == expectedAddressLength,
        message: "invalid number of child account Collection views returned"
    )
    assert(
        result[parent.address]!.length == expectedAddressLength,
        message: "invalid number of parent account Collection views returned"
    )
}

// --------------- End Test Cases --------------- 


// --------------- Transaction wrapper functions ---------------

pub fun setupChildAndParent_FilterKindAll(child: Test.Account, parent: Test.Account) {
    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(FilterKindAll)

    setupChildAccount(child, FilterKindAll)

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

pub fun setupChildAccount(_ acct: Test.Account, _ filterKind: String) {
    let factory = getTestAccount(nftFactory)
    let filter = getTestAccount(filterKind)

    setupFilter(filter, filterKind)
    setupFactoryManager(factory)

    setupNFTCollection(acct)

    txExecutor("hybrid-custody/setup_managed_account.cdc", [acct], [], nil, nil)
}

pub fun setupFactoryManager(_ acct: Test.Account) {
    txExecutor("factory/setup.cdc", [acct], [], nil, nil)
}

pub fun setupNFTCollection(_ acct: Test.Account) {
    txExecutor("example-nft/setup_full.cdc", [acct], [], nil, nil)
}

pub fun mintNFT(_ minter: Test.Account, receiver: Test.Account, name: String, description: String, thumbnail: String) {
    let filepath: String = "example-nft/mint_to_account.cdc"
    txExecutor(filepath, [minter], [receiver.address, name, description, thumbnail], nil, nil)
}

pub fun mintNFTDefault(_ minter: Test.Account, receiver: Test.Account) {
    return mintNFT(minter, receiver: receiver, name: "example nft", description: "lorem ipsum", thumbnail: "http://example.com/image.png")
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

pub fun addNFTCollectionToProxy(child: Test.Account, parent: Test.Account, isPublic: Bool) {
    txExecutor("hybrid-custody/add_example_nft_collection_to_proxy.cdc", [child], [parent.address, isPublic], nil, nil)
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

pub fun checkforAddresses(child: Test.Account, parent: Test.Account): Bool{
    let childAddressResult: [Address]? = (scriptExecutor("hybrid-custody/get_child_addresses.cdc", [parent.address])) as! [Address]?
    assert(childAddressResult?.contains(child.address) == true, message: "child address not found")

    let parentAddressResult: [Address]? = (scriptExecutor("hybrid-custody/get_parent_addresses.cdc", [child.address])) as! [Address]?
    assert(parentAddressResult?.contains(parent.address) == true, message: "parent address not found")
    return true
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
    let tx = Test.Transaction(
        code: txCode,
        authorizers: [signers[0].address],
        signers: signers,
        arguments: arguments,
    )

    let txResult = blockchain.executeTransaction(tx)
    if let err = txResult.error {
        if let expectedErrorMessage = expectedError {
            let ptr = getErrorMessagePointer(errorType: expectedErrorType!)
            let errMessage = err.message.slice(from: ptr, upTo: ptr + expectedErrorMessage.length)
            let hasEmittedCorrectMessage = errMessage == expectedErrorMessage ? true : false
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
    let capabilityProxyAccount = blockchain.createAccount()
    let capabilityFilterAccount = blockchain.createAccount()
    let capabilityFactoryAccount = blockchain.createAccount()

    // factory accounts
    let cpFactory = blockchain.createAccount()
    let providerFactory = blockchain.createAccount()
    let cpAndProviderFactory = blockchain.createAccount()

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
    
    // actual test accounts
    let parent = blockchain.createAccount()
    let child1 = blockchain.createAccount()
    let child2 = blockchain.createAccount()

    accounts = {
        "NonFungibleToken": nonFungibleToken,
        "MetadataViews": metadataViews,
        "ViewResolver": viewResolver,
        "HybridCustody": hybridCustodyAccount,
        "CapabilityProxy": capabilityProxyAccount,
        "CapabilityFilter": capabilityFilterAccount,
        "CapabilityFactory": capabilityFactoryAccount,
        "NFTCollectionPublicFactory": cpFactory,
        "NFTProviderAndCollectionFactory": providerFactory,
        "NFTProviderFactory": cpAndProviderFactory,
        "ArrayUtils": arrayUtils,
        "StringUtils": stringUtils,
        "AddressUtils": addressUtils,
        "ExampleNFT": exampleNFT,
        "parent": parent,
        "child1": child1,
        "child2": child2,
        "nftCapFactory": nftCapFactory
    }

    blockchain.useConfiguration(Test.Configuration({
        "FungibleToken": fungibleTokenAddress,
        "NonFungibleToken": accounts["NonFungibleToken"]!.address,
        "MetadataViews": accounts["MetadataViews"]!.address,
        "ViewResolver": accounts["ViewResolver"]!.address,
        "ArrayUtils": accounts["ArrayUtils"]!.address,
        "StringUtils": accounts["StringUtils"]!.address,
        "AddressUtils": accounts["AddressUtils"]!.address,
        "HybridCustody": accounts["HybridCustody"]!.address,
        "CapabilityProxy": accounts["CapabilityProxy"]!.address,
        "CapabilityFilter": accounts["CapabilityFilter"]!.address,
        "CapabilityFactory": accounts["CapabilityFactory"]!.address,
        "NFTCollectionPublicFactory": accounts["NFTCollectionPublicFactory"]!.address,
        "NFTProviderAndCollectionFactory": accounts["NFTProviderAndCollectionFactory"]!.address,
        "NFTProviderFactory": accounts["NFTProviderFactory"]!.address,
        "ExampleNFT": accounts["ExampleNFT"]!.address
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

    // our main contract is last
    deploy("CapabilityProxy", accounts["CapabilityProxy"]!, "../contracts/CapabilityProxy.cdc")
    deploy("CapabilityFilter", accounts["CapabilityFilter"]!, "../contracts/CapabilityFilter.cdc")
    deploy("CapabilityFactory", accounts["CapabilityFactory"]!, "../contracts/CapabilityFactory.cdc")
    deploy("NFTCollectionPublicFactory", accounts["NFTCollectionPublicFactory"]!, "../contracts/factories/NFTCollectionPublicFactory.cdc")
    deploy("NFTProviderAndCollectionFactory", accounts["NFTProviderAndCollectionFactory"]!, "../contracts/factories/NFTProviderAndCollectionFactory.cdc")
    deploy("NFTProviderFactory", accounts["NFTProviderFactory"]!, "../contracts/factories/NFTProviderFactory.cdc")
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
 