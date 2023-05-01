pub fun main(addr: Address): Int {
    let acct = getAuthAccount(addr)
    var count = 0

    acct.keys.forEach(fun (key: AccountKey): Bool {
        if !key.isRevoked {
            count = count + 1
        }
        return true
    })

    return count
}