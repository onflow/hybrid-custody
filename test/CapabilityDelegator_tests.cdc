import Test
import "test_helpers.cdc"

pub let adminAccount = blockchain.createAccount()
pub let creator = blockchain.createAccount()
pub let accounts: {String: Test.Account} = {}

pub let flowtyThumbnail = "https://storage.googleapis.com/flowty-images/flowty-logo.jpeg"

// BEGIN SECTION - Test Cases

pub fun testSetupDelegator() {
    setupDelegator(creator)

    let typ = CompositeType("A.01cf0e2f2f715450.CapabilityDelegator.DelegatorCreated")!
    let events = blockchain.eventsOfType(typ)
    Test.assertEqual(1, events.length)
}

pub fun testSetupNFTCollection() {
    setupNFTCollection(creator)
    mintNFTDefault(accounts["ExampleNFT"]!, receiver: creator)
}

pub fun testShareExampleNFTCollectionPublic() {
    sharePublicExampleNFT(creator)
    getExampleNFTCollectionFromDelegator(creator)
    findExampleNFTCollectionType(creator)
    getAllPublicContainsCollection(creator)
}

pub fun testShareExampleNFTCollectionPrivate() {
    sharePrivateExampleNFT(creator)
    getExampleNFTProviderFromDelegator(creator)
    findExampleNFTProviderType(creator)
    getAllPrivateContainsProvider(creator)
}

pub fun testRemoveExampleNFTCollectionPublic() {
    removePublicExampleNFT(creator)
    let scriptCode = loadCode("delegator/find_nft_collection_cap.cdc", "scripts")
    let scriptResult = blockchain.executeScript(scriptCode, [creator.address])

    Test.expect(scriptResult, Test.beFailed())
    Test.assert(contains(scriptResult.error!.message, "panic: no type found"))
}

pub fun testRemoveExampleNFTCollectionPrivate() {
    removePrivateExampleNFT(creator)
    let scriptCode = loadCode("delegator/find_nft_provider_cap.cdc", "scripts")
    let scriptResult = blockchain.executeScript(scriptCode, [creator.address])

    Test.expect(scriptResult, Test.beFailed())
    Test.assert(contains(scriptResult.error!.message, "panic: no type found"))
}

// END SECTION - Test Cases

pub fun setup() {
    accounts["NonFungibleToken"] = blockchain.createAccount()
    accounts["MetadataViews"] = blockchain.createAccount()
    accounts["ViewResolver"] = blockchain.createAccount()
    accounts["CapabilityDelegator"] = adminAccount
    accounts["ExampleNFT"] = blockchain.createAccount()
    accounts["creator"] = blockchain.createAccount()

    blockchain.useConfiguration(Test.Configuration({
        "NonFungibleToken": accounts["NonFungibleToken"]!.address,
        "MetadataViews": accounts["MetadataViews"]!.address,
        "ViewResolver": accounts["ViewResolver"]!.address,
        "CapabilityDelegator": accounts["CapabilityDelegator"]!.address,
        "ExampleNFT": accounts["ExampleNFT"]!.address
    }))

    // deploy standard libs first
    deploy("NonFungibleToken", accounts["NonFungibleToken"]!, "../modules/flow-nft/contracts/NonFungibleToken.cdc")
    deploy("MetadataViews", accounts["MetadataViews"]!, "../modules/flow-nft/contracts/MetadataViews.cdc")
    deploy("ViewResolver", accounts["ViewResolver"]!, "../modules/flow-nft/contracts/ViewResolver.cdc")

    // helper nft contract so we can actually talk to nfts with tests
    deploy("ExampleNFT", accounts["ExampleNFT"]!, "../modules/flow-nft/contracts/ExampleNFT.cdc")

    // our main contract is last
    deploy("CapabilityDelegator", accounts["CapabilityDelegator"]!, "../contracts/CapabilityDelegator.cdc")
}

// END SECTION - Helper functions

// BEGIN SECTION - transactions used in tests
pub fun setupDelegator(_ acct: Test.Account) {
    txExecutor("delegator/setup.cdc", [acct], [], nil, nil)
}

pub fun sharePublicExampleNFT(_ acct: Test.Account) {
    txExecutor("delegator/add_public_nft_collection.cdc", [acct], [], nil, nil)
}

pub fun sharePrivateExampleNFT(_ acct: Test.Account) {
    txExecutor("delegator/add_private_nft_collection.cdc", [acct], [], nil, nil)
}

pub fun removePublicExampleNFT(_ acct: Test.Account) {
    txExecutor("delegator/remove_public_nft_collection.cdc", [acct], [], nil, nil)
}

pub fun removePrivateExampleNFT(_ acct: Test.Account) {
    txExecutor("delegator/remove_private_nft_collection.cdc", [acct], [], nil, nil)
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

// END SECTION - transactions use in tests

// BEGIN SECTION - scripts used in tests

pub fun getExampleNFTCollectionFromDelegator(_ owner: Test.Account) {
    let borrowed = scriptExecutor("delegator/get_nft_collection.cdc", [owner.address])! as! Bool
    assert(borrowed, message: "failed to borrow delegator")
}

pub fun getExampleNFTProviderFromDelegator(_ owner: Test.Account) {
    let borrowed = scriptExecutor("delegator/get_nft_provider.cdc", [owner.address])! as! Bool
    assert(borrowed, message: "failed to borrow delegator")
}

pub fun getAllPublicContainsCollection(_ owner: Test.Account) {
    let success = scriptExecutor("delegator/get_all_public_caps.cdc", [owner.address])! as! Bool
    assert(success, message: "failed to borrow delegator")
}

pub fun getAllPrivateContainsProvider(_ owner: Test.Account) {
    let success = scriptExecutor("delegator/get_all_private_caps.cdc", [owner.address])! as! Bool
    assert(success, message: "failed to borrow delegator")
}

pub fun findExampleNFTCollectionType(_ owner: Test.Account) {
    let borrowed = scriptExecutor("delegator/find_nft_collection_cap.cdc", [owner.address])! as! Bool
    assert(borrowed, message: "failed to borrow delegator")
}

pub fun findExampleNFTProviderType(_ owner: Test.Account) {
    let borrowed = scriptExecutor("delegator/find_nft_provider_cap.cdc", [owner.address])! as! Bool
    assert(borrowed, message: "failed to borrow delegator")
}

// END SECTION - scripts used in tests
