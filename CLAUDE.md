# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an EIP-7702 proxy contract system designed to upgrade EOAs (Externally Owned Accounts) to smart accounts. The project implements a signature-based proxy pattern that enables secure account upgrades while preserving EOA control.

### Key Architecture Components

**Core Contracts (`src/`):**
- `EIP7702Proxy.sol`: Main proxy contract implementing ERC-1967 with signature-based initialization
- `NonceTracker.sol`: Global nonce management for replay protection
- `DefaultReceiver.sol`: Default implementation for token reception before initialization
- `validators/CoinbaseSmartWalletValidator.sol`: Account state validation logic

**Key Dependencies:**
- OpenZeppelin contracts for ERC-1967 proxy utilities and cryptography
- Solady for optimized account implementations
- Coinbase Smart Wallet for the reference implementation

### Core Proxy Pattern

The `EIP7702Proxy` extends the standard ERC-1967 proxy pattern with:
1. **Signature-based upgrades**: EOA must sign implementation changes
2. **Nonce-based replay protection**: Uses global `NonceTracker` for preventing replay attacks
3. **Fallback token reception**: Uses `DefaultReceiver` when no implementation is set
4. **State validation**: Validates account state after upgrades using validator contracts
5. **ERC-1271 signature fallback**: Supports both implementation-based and EOA-based signature validation

## Development Commands

### Build and Test
```bash
# Build contracts
forge build

# Run all tests
forge test

# Run tests with gas reporting
forge test --gas-report

# Run specific test file
forge test --match-path test/EIP7702Proxy/constructor.t.sol

# Run with verbosity for debugging
forge test -vvv
```

### Coverage
```bash
# Generate coverage report
forge coverage
```

### Local Development with EIP-7702
```bash
# Start local Anvil node with EIP-7702 support
anvil --odyssey

# Run upgrade script locally (requires --ffi for signature generation)
forge script script/UpgradeEOA.s.sol --rpc-url http://localhost:8545 --broadcast --ffi

# Run initialization script
forge script script/Initialize.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Testnet Deployment (Odyssey)
```bash
# Deploy and upgrade on Odyssey testnet
forge script script/UpgradeEOA.s.sol --rpc-url https://odyssey.ithaca.xyz --broadcast --ffi

# Initialize with new owner
forge script script/Initialize.s.sol --rpc-url https://odyssey.ithaca.xyz --broadcast
```

### Contract Verification
```bash
# Verify implementation contract
forge verify-contract \
    --verifier blockscout \
    --verifier-url "https://odyssey-explorer.ithaca.xyz/api" \
    --watch \
    --compiler-version "v0.8.23" \
    --num-of-optimizations 200 \
    <IMPLEMENTATION_ADDRESS> \
    lib/smart-wallet/src/CoinbaseSmartWallet.sol:CoinbaseSmartWallet

# Verify proxy template
forge verify-contract \
    --verifier blockscout \
    --verifier-url "https://odyssey-explorer.ithaca.xyz/api" \
    --watch \
    --compiler-version "v0.8.23" \
    --num-of-optimizations 200 \
    <PROXY_TEMPLATE_ADDRESS> \
    src/EIP7702Proxy.sol:EIP7702Proxy
```

## Environment Setup

Copy `.env.example` to `.env` and configure:
- `EOA_PRIVATE_KEY`: EOA to be upgraded
- `DEPLOYER_PRIVATE_KEY`: Account deploying contracts
- `NEW_OWNER_PRIVATE_KEY`: New smart wallet owner
- `PROXY_TEMPLATE_ADDRESS_ODYSSEY`: Deployed proxy address (from UpgradeEOA output)

## Important Notes

- This is experimental technology using EIP-7702
- Contracts are unaudited prototypes
- The `--ffi` flag is required for scripts that generate signatures
- Odyssey testnet by Ithaca has EIP-7702 enabled for testing
- The upgrade process is two-step: deploy/upgrade, then initialize