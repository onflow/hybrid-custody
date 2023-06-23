#allowAccountLinking

import "HybridCustody"

transaction {
    prepare(acct: AuthAccount) {
        let owned = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned not found")
        owned.seal()
    }
}