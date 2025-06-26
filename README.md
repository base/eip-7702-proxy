# EIP-7702 Proxy

A secure ERC-1967 proxy implementation for EIP-7702 smart accounts.

## Overview

The EIP-7702 Proxy provides a secure way to upgrade EOAs to smart contract wallets through EIP-7702 delegation. It solves critical security challenges in the EIP-7702 design space while allowing the use of existing smart account implementations.

## Key Features

### 🔒 Secure Initialization
- Signature-based authorization from the EOA for initial implementation setting and initialization
- Atomic implementation setting + initialization to prevent front-running
- Account state validation through implementation-specific configurable validator
- Reliable protection against signature replay through external nonce tracking

### 💾 Storage Management
- ERC-1967 compliant implementation storage
- Ability to set the ERC-1967 storage slot via the proxy itself
- Built-in token receiver for uninitialized state
- Safe handling of A → B → A delegation patterns

### 🔄 Upgradeability
- Implementation-agnostic design
- Compatible with any ERC-1967 implementation

## Deployment Addresses

### Deployed on all [networks](https://docs.base.org/smart-wallet/concepts/features/built-in/networks) supported by Coinbase Smart Wallet

| Contract | Address |
|----------|---------|
| EIP7702Proxy: [`0x7702cb554e6bFb442cb743A7dF23154544a7176C`](https://basescan.org/address/0x7702cb554e6bFb442cb743A7dF23154544a7176C#code)|
| NonceTracker: [`0xD0Ff13c28679FDd75Bc09c0a430a0089bf8b95a8`](https://basescan.org/address/0xD0Ff13c28679FDd75Bc09c0a430a0089bf8b95a8#code)|
| DefaultReceiver: [`0x2a8010A9D71D2a5AEA19D040F8b4797789A194a9`](https://basescan.org/address/0x2a8010A9D71D2a5AEA19D040F8b4797789A194a9#code)|
| CoinbaseSmartWalletValidator: [`0x79A33f950b90C7d07E66950daedf868BD0cDcF96`](https://basescan.org/address/0x79A33f950b90C7d07E66950daedf868BD0cDcF96#code)|

## Core Components

### EIP7702Proxy
- Manages safe implementation upgrades through `setImplementation`
- Validates EOA signatures for all state changes
- Provides fallback to `DefaultReceiver` when uninitialized
- Overrides `isValidSignature` to provide a final fallback `ecrecover` check

### NonceTracker
- External nonce management for signature validation in storage-safe location
- Prevents signature replay attacks
- Maintains nonce integrity across delegations

### IAccountStateValidator
- Interface for implementation-specific state validation
- Called to ensure correct initialization or other account state
- Reverts invalid state transitions

### DefaultReceiver
- Inherits from Solady's `Receiver`
- Provides a default implementation for token compatibility

## Usage

1. Deploy singleton instance of `EIP7702Proxy` with immutable parameters:
   - `NonceTracker` for signature security
   - `DefaultReceiver` for token compatibility

2. Sign an EIP-7702 authorization with the EOA to delegate to the `EIP7702Proxy`
3. Sign a payload for `setImplementation` with the EOA, which includes the new implementation address, initialization calldata, and the address of an account state validator
4. Submit transaction with EIP-7702 authorization and call to `setImplementation(bytes args, bytes signature)` with:
    - `address newImplementation`: address of the new implementation
    - `bytes calldata callData`: initialization calldata
    - `address validator`: address of the account state validator
    - `bytes calldata signature`: ECDSA signature over the initialization hash from the EOA
    - `bool allowCrossChainReplay`: whether to allow cross-chain replay

Now the EOA has been upgraded to the smart account implementation and had its state initialized.

If the smart account implementation supports UUPS upgradeability, it will work as designed by submitting upgrade calls to the account.

## Security

Audited by [Spearbit](https://spearbit.com/).

| Audit | Date | Report |
|--------|---------|---------|
| First private audit | 02/03/2025 | [Report](audits/Cantina-February-2025.pdf) |
| Second private audit | 03/05/2025 | [Report](audits/Cantina-March-2025.pdf) |
| Public competition | 04/13/2025| [Report](audits/Cantina-Competition-April-2025.pdf) |
