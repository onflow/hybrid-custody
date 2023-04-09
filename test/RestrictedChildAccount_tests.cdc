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
pub let childAccountName = "child1 account"

// BEGIN SECTION - Test Cases
pub fun testManagerSetup() {
    let txCode = loadCode("setup_manager.cdc", "transactions")
    let signer = accounts["parent"]!
    setupManager(signer)

    let isSetup = scriptExecutor("verify_manager.cdc", [signer.address])! as! Bool
    assert(isSetup, message: "setupFailed")
}

pub fun testShareAccount() {
    let child = accounts["child1"]!
    let parent = accounts["parent"]!
    let name = childAccountName
    let description = "lorem ipsum"
    let thumbnail = flowtyThumbnail

    publishSharedAccount(child, parent, name, description, thumbnail)
    claimSharedAccount(parent, child: child)

    hasChildAccount(parent, child, name: name)
}

pub fun testParentBorrowCollection() {
    let minter = accounts["ExampleNFT"]!
    let child = accounts["child1"]!
    let parent = accounts["parent"]!

    setupNFTCollection(child)
    mintNFTDefault(minter, receiver: child)

    // Test that we can borrow successfully. This is just for discoverability
    canBorrowCollectionPublic(parent, childAccountName)
}

pub fun testParentWithdrawNFT() {
    let minter = accounts["ExampleNFT"]!
    let child = accounts["child1"]!
    let parent = accounts["parent"]!

    setupNFTCollection(parent)

    let nftIDs = getNftIDs(child)
    assert(nftIDs.length > 0, message: "no nfts to withdraw")
    let withdrawID = nftIDs[0]

    let code = loadCode("withdraw_to_account.cdc", "transactions")
    txExecutor(code, [parent], [childAccountName, withdrawID], nil, nil)
    
    let parentIDs = getNftIDs(parent)
    assert(parentIDs.contains(withdrawID), message: "parent does not have expected nft id")
}

// END SECTION - Test Cases

pub fun setup() {
    // main contract account being tested
    let restrictedChildAccount = blockchain.createAccount()
    let capabilityProxyAccount = blockchain.createAccount()

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
        "RestrictedChildAccount": restrictedChildAccount,
        "CapabilityProxy": capabilityProxyAccount,
        "ArrayUtils": arrayUtils,
        "StringUtils": stringUtils,
        "AddressUtils": addressUtils,
        "ExampleNFT": exampleNFT,
        "parent": parent,
        "child1": child1,
        "child2": child2
    }

    blockchain.useConfiguration(Test.Configuration({
        "FungibleToken": accounts["FungibleToken"]!.address,
        "NonFungibleToken": accounts["NonFungibleToken"]!.address,
        "MetadataViews": accounts["MetadataViews"]!.address,
        "ViewResolver": accounts["ViewResolver"]!.address,
        "ArrayUtils": accounts["ArrayUtils"]!.address,
        "StringUtils": accounts["StringUtils"]!.address,
        "AddressUtils": accounts["AddressUtils"]!.address,
        "RestrictedChildAccount": accounts["RestrictedChildAccount"]!.address,
        "CapabilityProxy": accounts["CapabilityProxy"]!.address,
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
    deploy("RestrictedChildAccount", accounts["RestrictedChildAccount"]!, "../contracts/RestrictedChildAccount.cdc")
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
    return Test.readFile("./".concat(baseDirectory).concat("/").concat(fileName))
}
// END SECTION - Helper functions

// BEGIN SECTION - transactions used in tests

pub fun setupManager(_ signer: Test.Account) {
    let txCode = loadCode("setup_manager.cdc", "transactions")

    txExecutor(txCode, [signer], [], nil, nil)

    let isSetup = scriptExecutor("verify_manager.cdc", [signer.address])! as! Bool
    assert(isSetup, message: "setupFailed")
}

pub fun publishSharedAccount(_ child: Test.Account, _ parent: Test.Account, _ name: String, _ description: String, _ thumbnail: String) {
    let txCode = loadCode("publish_account.cdc", "transactions")
    txExecutor(txCode, [child], [parent.address, name, description, thumbnail], nil, nil)
}

pub fun claimSharedAccount(_ parent: Test.Account, child: Test.Account) {
    let txCode = loadCode("claim_account.cdc", "transactions")
    txExecutor(txCode, [parent], [child.address], nil, nil)
}

pub fun shareAndClaim_Default(_ parent: Test.Account, _ child: Test.Account) {
    let name = "child1 account"
    let description = "lorem ipsum"
    let thumbnail = flowtyThumbnail

    publishSharedAccount(child, parent, name, description, thumbnail)
    claimSharedAccount(parent, child: child)
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

// END SECTION - transactions use in tests


// BEGIN SECTION - scripts used in tests

pub fun hasChildAccount(_ parent: Test.Account, _ child: Test.Account, name: String) {
    let scriptCode = loadCode("has_child_account.cdc", "scripts")

    let hasAccount = scriptExecutor("has_child_account.cdc", [parent.address, child.address, name])! as! Bool
    assert(hasAccount, message: "failed to match child account")
}

pub fun canBorrowCollectionPublic(_ parent: Test.Account, _ childName: String) {
    let borrowed = scriptExecutor("borrow_collection.cdc", [parent.address, childName])! as! Bool
    assert(borrowed, message: "failed to borrow public nft collection from child account manager")
}

pub fun getNftIDs(_ account: Test.Account): [UInt64] {
    let ids = scriptExecutor("example-nft/get_ids.cdc", [account.address])! as! [UInt64]
    return ids
}

// END SECTION - scripts used in tests