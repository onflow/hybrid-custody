# Hybrid Custody

![Tests](https://github.com/onflow/hybrid-custody/actions/workflows/integration-tests.yml/badge.svg)
[![codecov](https://codecov.io/gh/onflow/hybrid-custody/branch/main/graph/badge.svg?token=5GWD5NHEKF)](https://codecov.io/gh/onflow/hybrid-custody)

**Please see [Flow's documentation about account
linking](https://developers.flow.com/concepts/hybrid-custody/guides/linking-accounts) for more information and
examples.**

This repo contains a primary contract for managing ChildAccounts to permit hybrid custody in scenarios where apps only
want to share a subset of resources on their accounts with various parents. In many cases, this will be a user's primary
wallet outside of the application a child account came from

Apps need assurances that their own resources are safe from malicious actors, so giving out full custody might not be
the form of hybrid custody that they want. In this model, the app still maintains control of their managed accounts, but
they can:

1. Share capabilities freely, with a few built-in controls over the types of capabilities that can be returned with some
   helper contracts (the `CapabilityFactory`, and `CapabilityFilter`)
1. Share additional capabilities (public or private) with a parent account via a `CapabilityDelegator` resource

## Deployment Details

| Network    | Address                                                                              |
| ---------- | ------------------------------------------------------------------------------------ |
| Testnet    | [0x294e44e1ec6993c6](https://testnet.contractbrowser.com/account/0x294e44e1ec6993c6) |
| Mainnet    | [0xd8a7e05a7ac670c0](https://contractbrowser.com/account/0xd8a7e05a7ac670c0)         |

### Hosted `CapabilityFactory` & `CapabilityFilter` Implementations

> :information_source: `CapabilityFactory.Manager` implementations and `CapabilityFilter.AllowAllFilter` have been
> deployed to the accounts below for generalized use cases to make account linking as easy as possible. These
> generalized implementations likely cover most use cases, but you'll want to weigh the decision to use them according
> to your risk tolerance and specific scenario.

| Use Case | Testnet Address | Mainnet Address |
| -------- | --------------- | --------------- |
| NFT Capability Factories       | [0x1055970ee34ef4dc](https://f.dnz.dev/0x1055970ee34ef4dc/storage/CapabilityFactory_0x294e44e1ec6993c6) | [0xee9ff4f07a2d6dad](https://f.dnz.dev/0xee9ff4f07a2d6dad/storage/CapabilityFactory_0xd8a7e05a7ac670c0) |
| FT Capability Factories        | [0x08bed9e8508ed20e](https://f.dnz.dev/0x08bed9e8508ed20e/storage/CapabilityFactory_0x294e44e1ec6993c6) | [0x410aa603925923d9](https://f.dnz.dev/0x410aa603925923d9/storage/CapabilityFactory_0xd8a7e05a7ac670c0) |
| NFT + FT Capability Factories  | [0x1b7fa5972fcb8af5](https://f.dnz.dev/0x1b7fa5972fcb8af5/storage/CapabilityFactory_0x294e44e1ec6993c6) | [0x071d382668250606](https://f.dnz.dev/0x071d382668250606/storage/CapabilityFactory_0xd8a7e05a7ac670c0) |
| AllowAllFilter                 | [0xe2664be06bb0fe62](https://f.dnz.dev/0xe2664be06bb0fe62/storage/CapabilityFilter_0x294e44e1ec6993c6) | [0x78e93a79b05d0d7d](https://f.dnz.dev/0x78e93a79b05d0d7d/storage/CapabilityFilter_0xd8a7e05a7ac670c0)  |

## Development

Follow the steps outlined below to set up your development environment.

1. **Initialize and Update Submodules**

   This project uses [Flow CLI's Dependency Manager](https://developers.flow.com/tools/flow-cli/dependency-manager). To
   install them, run the following command in your terminal:

   ```bash
   flow dependencies install
   ```

2. **Run Flow Emulator**

   Kickstart your development by running the flow emulator. Use the following command in your terminal:

   ```bash
   flow emulator start
   ```
