import Test
import "test_helpers.cdc"

pub let adminAccount = blockchain.createAccount()
pub let creator = blockchain.createAccount()

pub let flowtyThumbnail = "https://storage.googleapis.com/flowty-images/flowty-logo.jpeg"

// BEGIN SECTION - Test Cases

pub fun testGetProviderCapability() {
    setupNFTCollection(creator)

    scriptExecutor("factory/get_nft_provider_from_factory.cdc", [creator.address])
}

pub fun testGetSupportedTypesFromManager() {
    setupCapabilityFactoryManager(creator)

    let supportedTypes = scriptExecutor(
        "factory/get_supported_types_from_manager.cdc",
        [creator.address]
    )! as! [Type]
    Test.assertEqual(6, supportedTypes.length)
}

pub fun testAddFactoryFails() {
    let error = expectScriptFailure("test/add_nft_provider_factory.cdc", [creator.address])
    Test.assert(contains(error, "Factory of given type already exists"))
}

pub fun testAddFactorySucceeds() {
    txExecutor("test/add_nft_receiver_factory.cdc", [creator], [], nil, nil)

    let supportedTypes = scriptExecutor(
        "factory/get_supported_types_from_manager.cdc",
        [creator.address]
    )! as! [Type]
    Test.assertEqual(7, supportedTypes.length)

    let scriptResult = scriptExecutor(
        "test/get_nft_receiver_factory.cdc",
        [creator.address]
    )! as! Bool
    Test.assert(scriptResult)
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
    blockchain.useConfiguration(Test.Configuration({
        "CapabilityFactory": adminAccount.address,
        "ExampleNFT": adminAccount.address,
        "NFTProviderFactory": adminAccount.address,
        "NFTCollectionPublicFactory": adminAccount.address,
        "NFTProviderAndCollectionFactory": adminAccount.address,
        "FTProviderFactory": adminAccount.address,
        "FTBalanceFactory": adminAccount.address,
        "FTReceiverFactory": adminAccount.address
    }))

    // helper nft contract so we can actually talk to nfts with tests
    deploy("ExampleNFT", adminAccount, "../modules/flow-nft/contracts/ExampleNFT.cdc")

    // our main contract is last
    deploy("CapabilityFactory", adminAccount, "../contracts/CapabilityFactory.cdc")
    deploy("NFTProviderFactory", adminAccount, "../contracts/factories/NFTProviderFactory.cdc")
    deploy("NFTCollectionPublicFactory", adminAccount, "../contracts/factories/NFTCollectionPublicFactory.cdc")
    deploy("NFTProviderAndCollectionFactory", adminAccount, "../contracts/factories/NFTProviderAndCollectionFactory.cdc")
    deploy("FTProviderFactory", adminAccount, "../contracts/factories/FTProviderFactory.cdc")
    deploy("FTBalanceFactory", adminAccount, "../contracts/factories/FTBalanceFactory.cdc")
    deploy("FTReceiverFactory", adminAccount, "../contracts/factories/FTReceiverFactory.cdc")
}

// BEGIN SECTION - transactions used in tests

pub fun sharePublicExampleNFT(_ acct: Test.Account) {
    txExecutor("delegator/add_public_nft_collection.cdc", [acct], [], nil, nil)
}

pub fun setupNFTCollection(_ acct: Test.Account) {
    txExecutor("example-nft/setup_full.cdc", [acct], [], nil, nil)
}

pub fun mintNFT(_ minter: Test.Account, receiver: Test.Account, name: String, description: String, thumbnail: String) {
    txExecutor("example-nft/mint_to_account.cdc", [minter], [receiver.address, name, description, thumbnail], nil, nil)
}

pub fun mintNFTDefault(_ minter: Test.Account, receiver: Test.Account) {
    return mintNFT(minter, receiver: receiver, name: "example nft", description: "lorem ipsum", thumbnail: flowtyThumbnail)
}

pub fun setupCapabilityFactoryManager(_ acct: Test.Account) {
    txExecutor("factory/setup.cdc", [acct], [], nil, nil)
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
