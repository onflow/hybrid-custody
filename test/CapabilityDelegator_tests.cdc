import Test
import "test_helpers.cdc"
import "CapabilityDelegator"
import "NonFungibleToken"
import "ExampleNFT"

access(all) let admin = Test.getAccount(0x0000000000000007)
access(all) let creator = Test.createAccount()

access(all) let flowtyThumbnail = "https://storage.googleapis.com/flowty-images/flowty-logo.jpeg"

// BEGIN SECTION - Test Cases

access(all)
fun testSetupDelegator() {
    setupDelegator(creator)

    let typ = Type<CapabilityDelegator.DelegatorCreated>()
    let events = Test.eventsOfType(typ)
    Test.assertEqual(1, events.length)
}

access(all)
fun testSetupNFTCollection() {
    setupNFTCollection(creator)
    mintNFTDefault(admin, receiver: creator)
}

access(all)
fun testShareExampleNFTCollectionPublic() {
    sharePublicExampleNFT(creator)
    getExampleNFTCollectionFromDelegator(creator)
    findExampleNFTCollectionType(creator)
    getAllPublicContainsCollection(creator)

    let typ = Type<CapabilityDelegator.DelegatorUpdated>()
    let events = Test.eventsOfType(typ)
    Test.assertEqual(1, events.length)

    let e = events[0] as! CapabilityDelegator.DelegatorUpdated
    Test.assert(e.isPublic)
    Test.assert(e.active)

    let capabilityType = Type<Capability<&{ExampleNFT.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic}>>()
    Test.assertEqual(capabilityType, e.capabilityType)
}

access(all)
fun testShareExampleNFTCollectionPrivate() {
    sharePrivateExampleNFT(creator)
    getExampleNFTProviderFromDelegator(creator)
    findExampleNFTProviderType(creator)
    getAllPrivateContainsProvider(creator)

    let typ = Type<CapabilityDelegator.DelegatorUpdated>()
    let events = Test.eventsOfType(typ)
    Test.assertEqual(2, events.length)

    let e = events[1] as! CapabilityDelegator.DelegatorUpdated
    Test.assert(e.isPublic == false)
    Test.assert(e.active)

    let capabilityType = Type<Capability<auth(NonFungibleToken.Withdraw, NonFungibleToken.Owner) &{NonFungibleToken.Provider}>>()
    Test.assertEqual(capabilityType, e.capabilityType)
}

access(all)
fun testRemoveExampleNFTCollectionPublic() {
    removePublicExampleNFT(creator)

    let typ = Type<CapabilityDelegator.DelegatorUpdated>()
    let events = Test.eventsOfType(typ)
    Test.assertEqual(3, events.length)

    let e = events[2] as! CapabilityDelegator.DelegatorUpdated
    Test.assert(e.isPublic)
    Test.assert(e.active == false)

    let capabilityType = Type<Capability<&{ExampleNFT.ExampleNFTCollectionPublic, NonFungibleToken.CollectionPublic}>>()
    Test.assertEqual(capabilityType, e.capabilityType)

    let scriptCode = loadCode("delegator/find_nft_collection_cap.cdc", "scripts")
    let scriptResult = Test.executeScript(scriptCode, [creator.address])

    Test.expect(scriptResult, Test.beFailed())
    Test.assertError(
        scriptResult,
        errorMessage: "no type found"
    )
}

access(all)
fun testRemoveExampleNFTCollectionPrivate() {
    removePrivateExampleNFT(creator)

    let typ = Type<CapabilityDelegator.DelegatorUpdated>()
    let events = Test.eventsOfType(typ)
    Test.assertEqual(4, events.length)

    let e = events[3] as! CapabilityDelegator.DelegatorUpdated
    Test.assert(e.isPublic == false)
    Test.assert(e.active == false)

    let capabilityType = Type<Capability<auth(NonFungibleToken.Withdraw, NonFungibleToken.Owner) &{NonFungibleToken.Provider}>>()
    Test.assertEqual(capabilityType, e.capabilityType)

    let scriptCode = loadCode("delegator/find_nft_provider_cap.cdc", "scripts")
    let scriptResult = Test.executeScript(scriptCode, [creator.address])

    Test.expect(scriptResult, Test.beFailed())
    Test.assertError(
        scriptResult,
        errorMessage: "no type found"
    )
}

// END SECTION - Test Cases

access(all)
fun setup() {
    // helper nft contract so we can actually talk to nfts with tests
    deploy("ExampleNFT", "../contracts/standard/ExampleNFT.cdc")

    // our main contract is last
    deploy("CapabilityDelegator", "../contracts/CapabilityDelegator.cdc")
}

// END SECTION - Helper functions

// BEGIN SECTION - transactions used in tests
access(all)
fun setupDelegator(_ acct: Test.TestAccount) {
    txExecutor("delegator/setup.cdc", [acct], [], nil)
}

access(all)
fun sharePublicExampleNFT(_ acct: Test.TestAccount) {
    txExecutor("delegator/add_public_nft_collection.cdc", [acct], [], nil)
}

access(all)
fun sharePrivateExampleNFT(_ acct: Test.TestAccount) {
    txExecutor("delegator/add_private_nft_collection.cdc", [acct], [], nil)
}

access(all)
fun removePublicExampleNFT(_ acct: Test.TestAccount) {
    txExecutor("delegator/remove_public_nft_collection.cdc", [acct], [], nil)
}

access(all)
fun removePrivateExampleNFT(_ acct: Test.TestAccount) {
    txExecutor("delegator/remove_private_nft_collection.cdc", [acct], [], nil)
}

access(all)
fun setupNFTCollection(_ acct: Test.TestAccount) {
    txExecutor("example-nft/setup_full.cdc", [acct], [], nil)
}

access(all)
fun mintNFT(_ minter: Test.TestAccount, receiver: Test.TestAccount, name: String, description: String, thumbnail: String) {
    txExecutor("example-nft/mint_to_account.cdc", [minter], [receiver.address, name, description, thumbnail], nil)
}

access(all)
fun mintNFTDefault(_ minter: Test.TestAccount, receiver: Test.TestAccount) {
    return mintNFT(minter, receiver: receiver, name: "example nft", description: "lorem ipsum", thumbnail: flowtyThumbnail)
}

// END SECTION - transactions use in tests

// BEGIN SECTION - scripts used in tests

access(all)
fun getExampleNFTCollectionFromDelegator(_ owner: Test.TestAccount) {
    let borrowed = scriptExecutor("delegator/get_nft_collection.cdc", [owner.address])! as! Bool
    Test.assert(borrowed, message: "failed to borrow delegator")
}

access(all)
fun getExampleNFTProviderFromDelegator(_ owner: Test.TestAccount) {
    let borrowed = scriptExecutor("delegator/get_nft_provider.cdc", [owner.address])! as! Bool
    Test.assert(borrowed, message: "failed to borrow delegator")
}

access(all)
fun getAllPublicContainsCollection(_ owner: Test.TestAccount) {
    let success = scriptExecutor("delegator/get_all_public_caps.cdc", [owner.address])! as! Bool
    Test.assert(success, message: "failed to borrow delegator")
}

access(all)
fun getAllPrivateContainsProvider(_ owner: Test.TestAccount) {
    let success = scriptExecutor("delegator/get_all_private_caps.cdc", [owner.address])! as! Bool
    Test.assert(success, message: "failed to borrow delegator")
}

access(all)
fun findExampleNFTCollectionType(_ owner: Test.TestAccount) {
    let borrowed = scriptExecutor("delegator/find_nft_collection_cap.cdc", [owner.address])! as! Bool
    Test.assert(borrowed, message: "failed to borrow delegator")
}

access(all)
fun findExampleNFTProviderType(_ owner: Test.TestAccount) {
    let borrowed = scriptExecutor("delegator/find_nft_provider_cap.cdc", [owner.address])! as! Bool
    Test.assert(borrowed, message: "failed to borrow delegator")
}

// END SECTION - scripts used in tests
