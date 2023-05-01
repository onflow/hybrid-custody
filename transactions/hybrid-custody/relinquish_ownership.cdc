#allowAccountLinking

import "HybridCustody"

transaction {
    prepare(acct: AuthAccount) {
        let c = acct.borrow<&HybridCustody.ChildAccount>(from: HybridCustody.ChildStoragePath)
            ?? panic("child not found")
        c.seal()
    }
}