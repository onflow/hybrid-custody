# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Install Dependencies
```bash
flow dependencies install
```
Dependencies are managed via Flow CLI's Dependency Manager, pulling from on-chain sources defined in `flow.json`.

### Run Tests
```bash
sh test.sh
# Expands to:
flow test --cover --covercode="contracts" --coverprofile="coverage.lcov" test/*_tests.cdc
```

### Run a Single Test File
```bash
flow test test/HybridCustody_tests.cdc
flow test test/CapabilityDelegator_tests.cdc
flow test test/CapabilityFactory_tests.cdc
```

### Local Development
```bash
flow emulator start       # Start local emulator
flow deploy               # Deploy contracts to emulator
```

## Architecture

This project implements **Hybrid Custody** (account linking) on Flow: a model where an app retains control of a managed account while selectively sharing capabilities with a parent (e.g., a user's wallet).

### Core Contracts (`contracts/`)

**`HybridCustody.cdc`** — The primary contract. Defines three resources:
- `OwnedAccount` — Holds an `AuthAccount` capability for the child account. Published on the child account. The app creates and controls this. Can publish a `ChildAccount` capability to a parent.
- `ChildAccount` — Also lives on the child account. Scopes parent access via a `CapabilityFactory` and `CapabilityFilter`. A capability on this resource is shared to the parent via the account inbox.
- `Manager` — Lives on the parent account. Tracks all `ChildAccount` capabilities (shared children) and optionally holds `OwnedAccount` capabilities (owned children it fully controls).

**`CapabilityFilter.cdc`** — Determines which capabilities a parent can retrieve from a child. Three implementations:
- `AllowAllFilter` — Passthrough; all types allowed.
- `AllowlistFilter` — Only explicitly listed types are returned.
- `DenylistFilter` — All types except explicitly denied ones are returned.

**`CapabilityFactory.cdc`** — Abstracts capability retrieval from an account. A `Manager` resource contains `Factory` structs indexed by `Type`. Each `Factory` defines `getCapability()` (private) and `getPublicCapability()` (public). This solves Cadence's static typing constraint for castable capability retrieval.

**`CapabilityDelegator.cdc`** — A supplement to `CapabilityFactory` for sharing capabilities outside the standard NFT/FT interfaces. `Delegator` holds a map of public and private capabilities; public ones are accessible to anyone, private ones only through a `ChildAccount` reference.

### Factory Implementations (`contracts/factories/`)

Pre-built `CapabilityFactory.Factory` structs for common token standards:
- NFT: `NFTProviderFactory`, `NFTCollectionFactory`, `NFTCollectionPublicFactory`, `NFTProviderAndCollectionFactory`
- FT: `FTProviderFactory`, `FTReceiverFactory`, `FTBalanceFactory`, `FTReceiverBalanceFactory`, `FTAllFactory`, `FTVaultFactory`

Hosted instances of these factories are deployed to shared accounts on testnet and mainnet (see README for addresses).

### Test Contracts (`contracts/standard/`)

`ExampleNFT.cdc`, `ExampleNFT2.cdc`, `ExampleToken.cdc` — Test fixtures only; not deployed to production.

### Testing (`test/`)

Tests use Flow's Cadence-native `Test` framework (not Go). Test files end in `_tests.cdc`. The `test_helpers.cdc` file provides `txExecutor`, `scriptExecutor`, `expectScriptFailure`, and `deploy` helpers used by all test files.

In `flow.json`, the `testing` network alias maps all core contracts to address `0x0000000000000007`.

### Account Lifecycle (Publish/Redeem Pattern)

1. Child account creates `OwnedAccount` + configures `CapabilityFactory` and `CapabilityFilter`.
2. Child calls `publishToParent()` — places a `ChildAccount` capability in the parent's account inbox.
3. Parent calls `redeemAccount()` on their `Manager` — claims the inbox capability and registers the child.
4. Parent can now call `getCapabilityFromChild()` on their Manager, which is gated by the child's filter and factory.

### Deployments

| Network | Address |
|---------|---------|
| Testnet | `0x294e44e1ec6993c6` |
| Mainnet | `0xd8a7e05a7ac670c0` |
