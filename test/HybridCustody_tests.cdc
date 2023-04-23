import Test

pub var accounts: {String: Test.Account} = {}
pub var blockchain = Test.newEmulatorBlockchain()

pub let app = "app"
pub let child = "child"
pub let nftFactory = "nftFactory"
pub let exampleNFT = "ExampleNFT"

pub let FilterKindAll = "all"
pub let FilterKindAllowList = "allowlist"
pub let FilterKindDenyList = "denylist"

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

// pub fun testGetPublicCapabilityFromChildAccount() {
//     let tmp = blockchain.createAccount()    
//     setupChildAccount(tmp, FilterKindAll)
    
//     scriptExecutor("hybrid-custody/get_public_capability.cdc", [tmp.address])
// }

// pub fun testGetProviderCapabilityFromChildAccount() {
//     let tmp = blockchain.createAccount()    
//     setupChildAccount(tmp, FilterKindAll)
    
//     scriptExecutor("hybrid-custody/get_provider_capability.cdc", [tmp.address])
// }

// pub fun testGetProviderCapabilityFromChildAccount_DenylistFilter() {
//     let tmp = blockchain.createAccount()    
//     setupChildAccount(tmp, FilterKindDenyList)


//     let identifier = buildTypeIdentifier(getTestAccount(exampleNFT), exampleNFT, "Collection")
//     addTypeToFilter(getTestAccount(FilterKindDenyList), FilterKindDenyList, identifier)

//     expectScriptFailure("hybrid-custody/get_provider_capability.cdc", [tmp.address])
// }

// pub fun testGetProviderCapabilityFromChildAccount_AllowlistFilter() {
//     let tmp = blockchain.createAccount()    
//     setupChildAccount(tmp, FilterKindAllowList)

//     let identifier = buildTypeIdentifier(getTestAccount(exampleNFT), exampleNFT, "Collection")
//     addTypeToFilter(getTestAccount(FilterKindAllowList), FilterKindAllowList, identifier)

//     scriptExecutor("hybrid-custody/get_provider_capability.cdc", [tmp.address])
// }

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
    txExecutor("hybrid-custody/redeem_account.cdc", [parent], [child.address], nil, nil)

    scriptExecutor("hybrid-custody/has_address_as_child.cdc", [parent.address, child.address])
}

// --------------- End Test Cases --------------- 


// --------------- Transaction wrapper functions ---------------

pub fun setupAccountManager(_ acct: Test.Account) {
    txExecutor("hybrid-custody/setup_manager.cdc", [acct], [], nil, nil)
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

// ---------------- BEGIN General-purpose helper functions

pub fun buildTypeIdentifier(_ acct: Test.Account, _ contractName: String, _ suffix: String): String {
    let addrString = (acct.address as! Address).toString()
    return "A.".concat(addrString.slice(from: 2, upTo: addrString.length)).concat(".").concat(contractName).concat(".").concat(suffix)
}

// ---------------- END General-purpose helper functions

// ---------------- End Transaction wrapper functions

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

pub fun expectScriptFailure(_ scriptName: String, _ arguments: [AnyStruct]) {
    let scriptCode = loadCode(scriptName, "scripts")
    let scriptResult = blockchain.executeScript(scriptCode, arguments)

    assert(scriptResult.error != nil, message: "script error was expected but there is no error message")
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

pub fun getErrorMessagePointer(errorType: ErrorType) : Int {
    switch errorType {
        case ErrorType.TX_PANIC: return 159
        case ErrorType.TX_ASSERT: return 170
        case ErrorType.TX_PRE: return 174
        case ErrorType.CONTRACT_WITHDRAWBALANCE: return 679
        default: panic("Invalid error type")
    }

    return 0
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
    let fungibleToken = blockchain.createAccount()
    
    // other contracts used in tests
    let exampleNFT = blockchain.createAccount()
    
    // actual test accounts
    let parent = blockchain.createAccount()
    let child1 = blockchain.createAccount()
    let child2 = blockchain.createAccount()

    accounts = {
        "FungibleToken": fungibleToken,
        "NonFungibleToken": nonFungibleToken,
        "MetadataViews": metadataViews,
        "ViewResolver": viewResolver,
        "LinkedAccount": linkedAccount,
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
        "FungibleToken": accounts["FungibleToken"]!.address,
        "NonFungibleToken": accounts["NonFungibleToken"]!.address,
        "MetadataViews": accounts["MetadataViews"]!.address,
        "ViewResolver": accounts["ViewResolver"]!.address,
        "ArrayUtils": accounts["ArrayUtils"]!.address,
        "StringUtils": accounts["StringUtils"]!.address,
        "AddressUtils": accounts["AddressUtils"]!.address,
        "LinkedAccount": accounts["LinkedAccount"]!.address,
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
    deploy("FungibleToken", accounts["FungibleToken"]!, "../modules/flow-nft/contracts/utility/FungibleToken.cdc")
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
    deploy("LinkedAccount", accounts["LinkedAccount"]!, "../contracts/LinkedAccount.cdc")
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
    pub case CONTRACT_WITHDRAWBALANCE
}
// END SECTION: Helper functions
 