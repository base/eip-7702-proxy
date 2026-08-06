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
| EIP7702Proxy | [`0x7702cb554e6bFb442cb743A7dF23154544a7176C`](https://basescan.org/address/0x7702cb554e6bFb442cb743A7dF23154544a7176C#code)|
| NonceTracker | [`0xD0Ff13c28679FDd75Bc09c0a430a0089bf8b95a8`](https://basescan.org/address/0xD0Ff13c28679FDd75Bc09c0a430a0089bf8b95a8#code)|
| DefaultReceiver | [`0x2a8010A9D71D2a5AEA19D040F8b4797789A194a9`](https://basescan.org/address/0x2a8010A9D71D2a5AEA19D040F8b4797789A194a9#code)|
| CoinbaseSmartWalletValidator |  [`0x79A33f950b90C7d07E66950daedf868BD0cDcF96`](https://basescan.org/address/0x79A33f950b90C7d07E66950daedf868BD0cDcF96#code)|

## Deploying

All contracts are deployed deterministically via CREATE2, so they share the same addresses on every chain (see [Deployment Addresses](#deployment-addresses) above). Deployment is handled by [`script/Deploy.s.sol`](script/Deploy.s.sol), which deploys the full cluster and asserts that each resulting address matches its canonical value. A misconfigured deploy therefore reverts instead of silently landing at the wrong address.

### How determinism works

Deployments go through the canonical CREATE2 factory at `0x4e59b44847b379578588920cA78FbF26c0B4956C`, which is already present on most chains. A CREATE2 address depends only on the factory, the salt, and the contract init code (creation bytecode plus constructor args), and never on the deployer's account. The salts are fixed in `Deploy.s.sol`:

| Salt | Value | Used for |
|------|-------|----------|
| `DEPENDENCY_DEPLOYMENT_SALT` | `7702` | `CoinbaseSmartWalletValidator`, `NonceTracker`, `DefaultReceiver` |
| `PROXY_DEPLOYMENT_SALT` | `23662924` | `EIP7702Proxy` (gives the `0x7702cb...` vanity prefix) |

Because the address is a function of the init code, the compiler settings must match exactly or the address changes. They are pinned in `foundry.toml` (`via_ir = true`, `optimizer = true`, `optimizer_runs = 20000`, solc `0.8.23`). Do not override them when deploying.

### Deploy to a new chain

1. Confirm the CREATE2 factory exists on the target chain:
   ```bash
   cast code 0x4e59b44847b379578588920cA78FbF26c0B4956C --rpc-url <RPC_URL>
   ```
   If this returns `0x`, deploy [Arachnid's deterministic deployment proxy](https://github.com/Arachnid/deterministic-deployment-proxy) first, then continue.
2. Fund the deployer account on the target chain. The full cluster is roughly 1.6M gas total.
3. Optionally simulate first by running the command below without `--broadcast`.
4. Deploy and broadcast:
   ```bash
   forge script Deploy \
     --account <your-keystore-account> \
     --sender <deployer-address> \
     --rpc-url <RPC_URL> \
     --broadcast -vvvv
   ```

The asserts in the script guarantee the contracts either land at the canonical addresses or the transaction reverts.

### Verifying

For Etherscan-family explorers:

```bash
# CoinbaseSmartWalletValidator (constructor arg: CoinbaseSmartWallet implementation)
forge verify-contract --watch --chain-id <CHAIN_ID> \
  --constructor-args $(cast abi-encode "constructor(address)" 0x000100abaad02f1cfC8Bbe32bD5a564817339E72) \
  --etherscan-api-key <API_KEY> \
  0x79A33f950b90C7d07E66950daedf868BD0cDcF96 \
  src/validators/CoinbaseSmartWalletValidator.sol:CoinbaseSmartWalletValidator

# NonceTracker (no constructor args)
forge verify-contract --watch --chain-id <CHAIN_ID> --etherscan-api-key <API_KEY> \
  0xD0Ff13c28679FDd75Bc09c0a430a0089bf8b95a8 src/NonceTracker.sol:NonceTracker

# DefaultReceiver (no constructor args)
forge verify-contract --watch --chain-id <CHAIN_ID> --etherscan-api-key <API_KEY> \
  0x2a8010A9D71D2a5AEA19D040F8b4797789A194a9 src/DefaultReceiver.sol:DefaultReceiver

# EIP7702Proxy (constructor args: NonceTracker, DefaultReceiver)
forge verify-contract --watch --chain-id <CHAIN_ID> \
  --constructor-args $(cast abi-encode "constructor(address,address)" 0xD0Ff13c28679FDd75Bc09c0a430a0089bf8b95a8 0x2a8010A9D71D2a5AEA19D040F8b4797789A194a9) \
  --etherscan-api-key <API_KEY> \
  0x7702cb554e6bFb442cb743A7dF23154544a7176C src/EIP7702Proxy.sol:EIP7702Proxy
```

For Blockscout explorers, add `--verifier blockscout --verifier-url https://<explorer-host>/api?` to each command (no API key required).

### Deploying without this repo

Because CREATE2 ignores the sender, anyone can reproduce the same addresses on a new chain by replaying the original deployment calldata against the factory, with no source checkout or compiler setup required. Each original deployment is a transaction sent to `0x4e59b44847b379578588920cA78FbF26c0B4956C` whose calldata is `salt (32 bytes) ++ init code`. Copy that calldata from a chain where the contracts already exist and resend it:

```bash
# Read the calldata from an existing deployment transaction
cast tx <DEPLOY_TX_HASH> input --rpc-url <SOURCE_RPC>

# Replay it on the new chain (deploy the dependencies before the proxy)
cast send 0x4e59b44847b379578588920cA78FbF26c0B4956C <CALLDATA> \
  --rpc-url <NEW_RPC> --account <your-keystore-account>
```

This reuses the exact init code byte-for-byte, so it produces identical addresses and avoids compiler-setting mismatches entirely.

### Notes

- `CoinbaseSmartWalletValidator` takes the Coinbase Smart Wallet implementation (`0x000100abaad02f1cfC8Bbe32bD5a564817339E72`) as a constructor argument. This is baked into its init code and does not need to exist for deployment to succeed, but the validator is only usable on chains where that implementation is also deployed.

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
- Inherits from Solady `Receiver`
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
