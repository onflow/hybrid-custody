import "RestrictedChildAccount"
import "MetadataViews"

transaction(childAddress: Address) {
  let managerRef: &RestrictedChildAccount.Manager
  let sharedAccount: &RestrictedChildAccount.SharedAccount

  prepare(signer: AuthAccount) {
    if signer.borrow<&RestrictedChildAccount.Manager>(from: RestrictedChildAccount.StoragePath) == nil {
      signer.save(<-RestrictedChildAccount.createManager(), to: RestrictedChildAccount.StoragePath)
    }

    if !signer.getCapability<&RestrictedChildAccount.Manager{RestrictedChildAccount.ManagerPublic}>(RestrictedChildAccount.PublicPath).check() {
        signer.unlink(RestrictedChildAccount.PublicPath)
        signer.link<&RestrictedChildAccount.Manager{RestrictedChildAccount.ManagerPublic}>(
            RestrictedChildAccount.PublicPath,
            target: RestrictedChildAccount.StoragePath
        )
    }

    self.managerRef = signer.borrow<&RestrictedChildAccount.Manager>(from: RestrictedChildAccount.StoragePath)!
    let cap = signer.inbox.claim<&RestrictedChildAccount.SharedAccount>(
        RestrictedChildAccount.InboxName,
        provider: childAddress
      ) ?? panic(
        "No SharedAccount Capability available from given provider"
        .concat(childAddress.toString())
        .concat(" with name ")
        .concat(RestrictedChildAccount.InboxName)
      )
    assert(cap.check(), message: "Published capability check failed")

    self.sharedAccount = cap.borrow() ?? panic("no shared account found")
  }

  execute {
    let a <- self.sharedAccount.pop()
    self.managerRef.registerAccount(<- a)
  }
}