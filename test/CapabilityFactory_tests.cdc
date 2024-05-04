import Test
import "test_helpers.cdc"
import "FungibleToken"
import "NonFungibleToken"

access(all) let creator = Test.createAccount()

access(all) let flowtyThumbnail = "https://storage.googleapis.com/flowty-images/flowty-logo.jpeg"

// BEGIN SECTION - Test Cases

access(all)
fun testGetNFTProviderCapability() {
    setupNFTCollection(creator)

    scriptExecutor("factory/get_nft_provider_from_factory.cdc", [creator.address])
}

access(all)
fun testGetFTReceiverCapability() {
    txExecutor("example-token/setup.cdc", [creator], [], nil)

    scriptExecutor("factory/get_ft_receiver_from_factory.cdc", [creator.address])
}

access(all)
fun testGetSupportedTypesFromManager() {
    setupCapabilityFactoryManager(creator)

    let supportedTypes = scriptExecutor(
        "factory/get_supported_types_from_manager.cdc",
        [creator.address]
    )! as! [Type]

    let expectedTypes = [
        Type<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>(),
        Type<&{FungibleToken.Balance}>(),
        Type<&{FungibleToken.Receiver}>(),
        Type<&{FungibleToken.Receiver, FungibleToken.Balance}>(),
        Type<auth(FungibleToken.Withdraw) &{FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance}>(),
        Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(),
        Type<&{NonFungibleToken.CollectionPublic}>(),
        Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider}>()
    ]
    for e in expectedTypes {
        Test.assert(supportedTypes.contains(e), message: "missing expected type in supported types")
    }
}

access(all)
fun testAddFactoryFails() {
    expectScriptFailure(
        "test/add_type_for_nft_provider_factory.cdc",
        [creator.address, Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider}>()],
        "Factory of given type already exists"
    )
}

access(all)
fun testAddFactorySucceeds() {
    txExecutor("test/add_type_for_nft_provider_factory.cdc", [creator], [Type<&{NonFungibleToken.Receiver}>()], nil)

    let supportedTypes = scriptExecutor(
        "factory/get_supported_types_from_manager.cdc",
        [creator.address]
    )! as! [Type]

    let expectedTypes = [
        Type<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>(),
        Type<&{FungibleToken.Balance}>(),
        Type<&{FungibleToken.Receiver}>(),
        Type<&{FungibleToken.Receiver, FungibleToken.Balance}>(),
        Type<auth(FungibleToken.Withdraw) &{FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance}>(),
        Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(),
        Type<&{NonFungibleToken.CollectionPublic}>(),
        Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider}>(),
        Type<&{NonFungibleToken.Receiver}>()
    ]

    for e in expectedTypes {
        Test.assert(supportedTypes.contains(e), message: "missing expected type in supportedTypes")
    }

    for type in supportedTypes {
        let factorySuccess = scriptExecutor(
            "test/get_type_from_factory.cdc",
            [creator.address, type]
        )! as! Bool
        Test.assert(factorySuccess)
    }
}

access(all)
fun testUpdateNFTProviderFactory() {
    let tmp = Test.createAccount()
    setupNFTCollection(tmp)

    setupCapabilityFactoryManager(tmp)

    scriptExecutor("test/update_nft_provider_factory.cdc", [tmp.address])
}

access(all)
fun testRemoveNFTProviderFactory() {
    let tmp = Test.createAccount()
    setupNFTCollection(tmp)

    setupCapabilityFactoryManager(tmp)

    Test.assert(
        (scriptExecutor("test/remove_nft_provider_factory.cdc", [tmp.address]) as! Bool?)!,
        message: "Removing NFTProviderFactory failed"
    )
}

access(all)
fun testSetupNFTManager() {
    let tmp = Test.createAccount()
    txExecutor("factory/setup_nft_manager.cdc", [tmp], [], nil)

    let supportedTypes = scriptExecutor("factory/get_supported_types_from_manager.cdc", [tmp.address])! as! [Type]

    let expectedTypes = [
        Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(),
        Type<&{NonFungibleToken.CollectionPublic}>(),
        Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider}>()
    ]
    
    for e in expectedTypes {
        Test.assert(supportedTypes.contains(e), message: "missing type in supportedTypes: ".concat(e.identifier))
    }

    for type in supportedTypes {
        let factorySuccess = scriptExecutor(
            "test/get_type_from_factory.cdc",
            [tmp.address, type]
        )! as! Bool
        Test.assert(factorySuccess)
    }
}

access(all)
fun testSetupFTManager() {
    let tmp = Test.createAccount()
    txExecutor("factory/setup_ft_manager.cdc", [tmp], [], nil)

    let supportedTypes = scriptExecutor("factory/get_supported_types_from_manager.cdc", [tmp.address])! as! [Type]

    let expectedTypes = [
        Type<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>(),
        Type<&{FungibleToken.Balance}>(),
        Type<&{FungibleToken.Receiver}>(),
        Type<&{FungibleToken.Receiver, FungibleToken.Balance}>(),
        Type<auth(FungibleToken.Withdraw) &{FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance}>()
    ]

    for e in expectedTypes {
        Test.assert(supportedTypes.contains(e), message: "missing type in supportedTypes: ".concat(e.identifier))
    }

    for type in supportedTypes {
        let factorySuccess = scriptExecutor(
            "test/get_type_from_factory.cdc",
            [tmp.address, type]
        )! as! Bool
        Test.assert(factorySuccess)
    }
}

access(all)
fun testSetupNFTFTManager() {
    let tmp = Test.createAccount()
    setupCapabilityFactoryManager(tmp)

    let supportedTypes = scriptExecutor("factory/get_supported_types_from_manager.cdc", [tmp.address])! as! [Type]

    let expectedTypes = [
        Type<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>(),
        Type<&{FungibleToken.Balance}>(),
        Type<&{FungibleToken.Receiver}>(),
        Type<&{FungibleToken.Receiver, FungibleToken.Balance}>(),
        Type<auth(FungibleToken.Withdraw) &{FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance}>(),
        Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(),
        Type<&{NonFungibleToken.CollectionPublic}>(),
        Type<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider}>()
    ]

    for e in expectedTypes {
        Test.assert(supportedTypes.contains(e), message: "missing type in supportedTypes: ".concat(e.identifier))
    }

    for type in supportedTypes {
        let factorySuccess = scriptExecutor(
            "test/get_type_from_factory.cdc",
            [tmp.address, type]
        )! as! Bool
        Test.assert(factorySuccess)
    }
}

// END SECTION - Test Cases

access(all)
fun setup() {
    // helper nft & ft contract so we can actually talk to nfts & fts with tests
    deploy("ExampleNFT", "../contracts/standard/ExampleNFT.cdc")
    deploy("ExampleToken", "../contracts/standard/ExampleToken.cdc")

    // our main contract is last
    deploy("CapabilityFactory", "../contracts/CapabilityFactory.cdc")
    deploy("NFTProviderFactory", "../contracts/factories/NFTProviderFactory.cdc")
    deploy("NFTCollectionPublicFactory", "../contracts/factories/NFTCollectionPublicFactory.cdc")
    deploy("NFTProviderAndCollectionFactory", "../contracts/factories/NFTProviderAndCollectionFactory.cdc")
    deploy("FTProviderFactory", "../contracts/factories/FTProviderFactory.cdc")
    deploy("FTBalanceFactory", "../contracts/factories/FTBalanceFactory.cdc")
    deploy("FTReceiverFactory", "../contracts/factories/FTReceiverFactory.cdc")
    deploy("FTReceiverBalanceFactory", "../contracts/factories/FTReceiverBalanceFactory.cdc")
    deploy("FTAllFactory", "../contracts/factories/FTAllFactory.cdc")
}

// BEGIN SECTION - transactions used in tests

access(all)
fun setupNFTCollection(_ acct: Test.TestAccount) {
    txExecutor("example-nft/setup_full.cdc", [acct], [], nil)
}

access(all)
fun setupCapabilityFactoryManager(_ acct: Test.TestAccount) {
    txExecutor("factory/setup_nft_ft_manager.cdc", [acct], [], nil)
}

// END SECTION - transactions use in tests
