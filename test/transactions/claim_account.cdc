import ReadOnlyChildAccount from "ReadOnlyChildAccount"
import MetadataViews from "MetadataViews"

transaction(childAddress: Address) {
  let managerRef: &ReadOnlyChildAccount.Manager
  let sharedAccount: &ReadOnlyChildAccount.SharedAccount

  prepare(signer: AuthAccount) {
    if signer.borrow<&ReadOnlyChildAccount.Manager>(from: ReadOnlyChildAccount.StoragePath) == nil {
      signer.save(<-ReadOnlyChildAccount.createManager(), to: ReadOnlyChildAccount.StoragePath)
    }

    if !signer.getCapability<&ReadOnlyChildAccount.Manager{ReadOnlyChildAccount.ManagerPublic}>(ReadOnlyChildAccount.PublicPath).check() {
        signer.unlink(ReadOnlyChildAccount.PublicPath)
        signer.link<&ReadOnlyChildAccount.Manager{ReadOnlyChildAccount.ManagerPublic}>(
            ReadOnlyChildAccount.PublicPath,
            target: ReadOnlyChildAccount.StoragePath
        )
    }

    self.managerRef = signer.borrow<&ReadOnlyChildAccount.Manager>(from: ReadOnlyChildAccount.StoragePath)!
    let cap = signer.inbox.claim<&ReadOnlyChildAccount.SharedAccount>(
        ReadOnlyChildAccount.InboxName,
        provider: childAddress
      ) ?? panic(
        "No SharedAccount Capability available from given provider"
        .concat(childAddress.toString())
        .concat(" with name ")
        .concat(ReadOnlyChildAccount.InboxName)
      )
    assert(cap.check(), message: "Published capability check failed")

    self.sharedAccount = cap.borrow() ?? panic("no shared account found")
  }

  execute {
    let a <- self.sharedAccount.pop()
    self.managerRef.registerAccount(<- a)
  }
}