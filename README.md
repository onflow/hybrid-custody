# Hybrid Custody

**NOTE: This contract is still under development, its address is likely to be redeployed to testnet once it is finished**

This repo contains a primary contract for managing ChildAccounts to permit
hybrid custody in scenarios where apps only want to share a subset of resources on their
accounts with various parents. In many cases, this will be a user's primary wallet outside of the
application a child account came from

Apps need assurances that their own resources are safe from malicious actors, so giving out full
custody might not be the form of hybrid custody that they want. In this model, the app still
maintains control of their managed accounts, but they can:

1. Share capabilities freely, with a few built-in controls over the types of capabilities that can be returned with some helper contracts (the `CapabilityFactory`, and `CapabilityFilter`)
1. Share additional capabilities (public or private) with a parent account via a `CapabilityProxy` resource

| Network |  Address           |
|---------|--------------------|
| Testnet | [0x96b15ff6dfde11fe](https://testnet.contractbrowser.com/account/0x96b15ff6dfde11fe) |
