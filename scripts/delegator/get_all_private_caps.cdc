import "CapabilityDelegator"

import "NonFungibleToken"
import "ExampleNFT"

access(all) fun main(address: Address): Bool {
    let privateCaps: [Capability] = getAuthAccount<auth(Capabilities) &Account>(address).capabilities.storage.issue<auth(Capabilities) &{CapabilityDelegator.GetterPrivate}>(CapabilityDelegator.StoragePath)
        .borrow()
        ?.getAllPrivate()
        ?? panic("could not borrow delegator")

    let desiredType: Type = Type<Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider}>>()

    return privateCaps.length == 1 && privateCaps[0].getType() == desiredType
}