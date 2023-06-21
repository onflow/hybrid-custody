#allowAccountLinking

import "HybridCustody"

transaction(owner: Address) {
    prepare(acct: AuthAccount) {
        let c = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.ChildStoragePath)
            ?? panic("child not found")
        c.giveOwnership(to: owner)
    }
}