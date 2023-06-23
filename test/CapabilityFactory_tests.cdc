import Test

pub var blockchain = Test.newEmulatorBlockchain()
pub var accounts: {String: Test.Account} = {}

pub enum ErrorType: UInt8 {
    pub case TX_PANIC
    pub case TX_ASSERT
    pub case TX_PRE
    pub case CONTRACT_WITHDRAWBALANCE
}

pub let flowtyThumbnail = "https://storage.googleapis.com/flowty-images/flowty-logo.jpeg"

// BEGIN SECTION - Test Cases
pub fun testGetProviderCapability() {
    let signer = accounts["creator"]!
    setupNFTCollection(signer)

    scriptExecutor("factory/get_nft_provider_from_factory.cdc", [signer.address])
}

pub fun testGetSupportedTypesFromManager() {
    let tmp = blockchain.createAccount()
    setupNFTCollection(tmp)

    setupCapabilityFactoryManager(tmp)

    let supportedTypes = (scriptExecutor("factory/get_supported_types_from_manager.cdc", [tmp.address]) as! [Type]?)!
    assert(
        supportedTypes.length == 4,
        message: "Removing NFTProviderFactory failed"
    )
}

pub fun testAddFactoryFails() {
    let tmp = blockchain.createAccount()
    setupNFTCollection(tmp)

    setupCapabilityFactoryManager(tmp)

    let error = expectScriptFailure("test/add_nft_provider_factory.cdc", [tmp.address])
    assert(
        contains(error, "Factory of given type already exists"),
        message: "Adding existing Factory should have failed"
    )
}

pub fun testUpdateNFTProviderFactory() {
    let tmp = blockchain.createAccount()
    setupNFTCollection(tmp)

    setupCapabilityFactoryManager(tmp)

    scriptExecutor("test/update_nft_provider_factory.cdc", [tmp.address])
}

pub fun testRemoveNFTProviderFactory() {
    let tmp = blockchain.createAccount()
    setupNFTCollection(tmp)

    setupCapabilityFactoryManager(tmp)

    assert(
        (scriptExecutor("test/remove_nft_provider_factory.cdc", [tmp.address]) as! Bool?)!,
        message: "Removing NFTProviderFactory failed"
    )
}

// END SECTION - Test Cases

pub fun setup() {
    // main contract account being tested
    let capabilityFactory = blockchain.createAccount()
    let nftCollectionPublicFactory = blockchain.createAccount()
    let nftProviderAndCollectionFactory = blockchain.createAccount()
    let nftProviderFactory = blockchain.createAccount()
    let ftProviderFactory = blockchain.createAccount()

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
    let creator = blockchain.createAccount()
    let receiver = blockchain.createAccount()

    accounts = {
        "FungibleToken": fungibleToken,
        "NonFungibleToken": nonFungibleToken,
        "MetadataViews": metadataViews,
        "ViewResolver": viewResolver,
        "CapabilityFactory": capabilityFactory,
        "NFTCollectionPublicFactory": nftCollectionPublicFactory,
        "NFTProviderAndCollectionFactory": nftProviderAndCollectionFactory,
        "NFTProviderFactory": nftProviderFactory,
        "FTProviderFactory": ftProviderFactory,
        "ArrayUtils": arrayUtils,
        "StringUtils": stringUtils,
        "AddressUtils": addressUtils,
        "ExampleNFT": exampleNFT,
        "creator": creator,
        "receiver": receiver
    }

    blockchain.useConfiguration(Test.Configuration({
        "FungibleToken": accounts["FungibleToken"]!.address,
        "NonFungibleToken": accounts["NonFungibleToken"]!.address,
        "MetadataViews": accounts["MetadataViews"]!.address,
        "ViewResolver": accounts["ViewResolver"]!.address,
        "ArrayUtils": accounts["ArrayUtils"]!.address,
        "StringUtils": accounts["StringUtils"]!.address,
        "AddressUtils": accounts["AddressUtils"]!.address,
        "CapabilityFactory": accounts["CapabilityFactory"]!.address,
        "NFTCollectionPublicFactory": accounts["NFTCollectionPublicFactory"]!.address,
        "NFTProviderAndCollectionFactory": accounts["NFTProviderAndCollectionFactory"]!.address,
        "NFTProviderFactory": accounts["NFTProviderFactory"]!.address,
        "FTProviderFactory": accounts["FTProviderFactory"]!.address,
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
    deploy("CapabilityFactory", accounts["CapabilityFactory"]!, "../contracts/CapabilityFactory.cdc")
    deploy("NFTCollectionPublicFactory", accounts["NFTCollectionPublicFactory"]!, "../contracts/factories/NFTCollectionPublicFactory.cdc")
    deploy("NFTProviderAndCollectionFactory", accounts["NFTProviderAndCollectionFactory"]!, "../contracts/factories/NFTProviderAndCollectionFactory.cdc")
    deploy("NFTProviderFactory", accounts["NFTProviderFactory"]!, "../contracts/factories/NFTProviderFactory.cdc")
    deploy("FTProviderFactory", accounts["FTProviderFactory"]!, "../contracts/factories/FTProviderFactory.cdc")
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

pub fun txExecutor(_ txCode: String, _ signers: [Test.Account], _ arguments: [AnyStruct], _ expectedError: String?, _ expectedErrorType: ErrorType?): Bool {
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

pub fun loadCode(_ fileName: String, _ baseDirectory: String): String {
    return Test.readFile("../".concat(baseDirectory).concat("/").concat(fileName))
}

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
// END SECTION - Helper functions

// BEGIN SECTION - transactions used in tests
pub fun sharePublicExampleNFT(_ acct: Test.Account) {
    let txCode = loadCode("delegator/add_public_nft_collection.cdc", "transactions")
    txExecutor(txCode, [acct], [], nil, nil)
}

pub fun setupNFTCollection(_ acct: Test.Account) {
    let txCode = loadCode("example-nft/setup_full.cdc", "transactions")
    txExecutor(txCode, [acct], [], nil, nil)
}

pub fun mintNFT(_ minter: Test.Account, receiver: Test.Account, name: String, description: String, thumbnail: String) {
    let txCode = loadCode("example-nft/mint_to_account.cdc", "transactions")
    txExecutor(txCode, [minter], [receiver.address, name, description, thumbnail], nil, nil)
}

pub fun mintNFTDefault(_ minter: Test.Account, receiver: Test.Account) {
    return mintNFT(minter, receiver: receiver, name: "example nft", description: "lorem ipsum", thumbnail: flowtyThumbnail)
}

pub fun setupCapabilityFactoryManager(_ acct: Test.Account) {
    let txCode = loadCode("factory/setup.cdc", "transactions")
    txExecutor(txCode, [acct], [], nil, nil)
}

// END SECTION - transactions use in tests


// BEGIN SECTION - scripts used in tests

pub fun getExampleNFTCollectionFromDelegator(_ owner: Test.Account) {
    let borrowed = scriptExecutor("delegator/get_nft_collection.cdc", [owner.address])! as! Bool
    assert(borrowed, message: "failed to borrow delegator")
}

pub fun findExampleNFTCollectionType(_ owner: Test.Account) {
    let borrowed = scriptExecutor("delegator/find_nft_collection_cap.cdc", [owner.address])! as! Bool
    assert(borrowed, message: "failed to borrow delegator")
}

pub fun expectScriptFailure(_ scriptName: String, _ arguments: [AnyStruct]): String {
    let scriptCode = loadCode(scriptName, "scripts")
    let scriptResult = blockchain.executeScript(scriptCode, arguments)

    assert(scriptResult.error != nil, message: "script error was expected but there is no error message")
    return scriptResult.error!.message
}

// END SECTION - scripts used in tests