#allowAccountLinking

import "HybridCustody"

transaction {
    prepare(acct: AuthAccount) {
        let c = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.ChildStoragePath)
            ?? panic("child not found")
        c.seal()
    }
}