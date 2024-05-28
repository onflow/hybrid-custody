import "FungibleToken"
import "FungibleTokenMetadataViews"
import "ExampleToken"

//EMULATOR transaction only! Emulator contract does not require admin resource

/// This transaction is what the minter Account uses to mint new tokens
/// They provide the recipient address and amount to mint, and the tokens
/// are transferred to the address after minting

transaction(recipient: Address, amount: UFix64) {
    /// Reference to the Fungible Token Receiver of the recipient
    let tokenReceiver: &{FungibleToken.Receiver}

    /// The total supply of tokens before the burn
    let supplyBefore: UFix64

    prepare(signer: auth(Storage, Capabilities) &Account) {
        self.supplyBefore = ExampleToken.totalSupply

        let vaultData = ExampleToken.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
            ?? panic("Could not get the vault data view for ExampleToken")

        // Get the account of the recipient and borrow a reference to their receiver
        self.tokenReceiver = getAccount(recipient).capabilities.get<&{FungibleToken.Receiver}>(vaultData.receiverPath)!.borrow()
            ?? panic("Unable to borrow receiver reference")
    }

    execute {
        // Create a minter and mint tokens
        let minter <- ExampleToken.createNewMinter(allowedAmount: amount)
        let mintedVault <- minter.mintTokens(amount: amount)

        // Deposit them to the receiever
        self.tokenReceiver.deposit(from: <-mintedVault)

        destroy minter
    }

    post {
        ExampleToken.totalSupply == self.supplyBefore + amount: "The total supply must be increased by the amount"
    }
}
 