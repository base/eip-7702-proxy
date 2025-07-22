# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an EIP-7702 proxy contract system that provides a secure way to upgrade EOAs to smart contract wallets through EIP-7702 delegation. The project implements a signature-based proxy pattern that enables secure account upgrades while preserving EOA control and preventing common attack vectors.

### Key Architecture Components

**Core Contracts (`src/`):**
- `EIP7702Proxy.sol`: Main proxy contract implementing ERC-1967 with signature-based implementation setting
- `NonceTracker.sol`: Global nonce management for replay protection
- `DefaultReceiver.sol`: Default implementation for token reception before initialization
- `validators/CoinbaseSmartWalletValidator.sol`: Account state validation logic for Coinbase Smart Wallet

**Key Dependencies:**
- OpenZeppelin contracts for ERC-1967 proxy utilities and cryptography
- Solady for optimized account implementations and receiver functionality
- Coinbase Smart Wallet for the reference implementation

### Core Proxy Pattern

The `EIP7702Proxy` extends the standard ERC-1967 proxy pattern with:
1. **Signature-based upgrades**: EOA must sign implementation changes with expiry timestamps
2. **Nonce-based replay protection**: Uses global `NonceTracker` for preventing replay attacks
3. **Account state validation**: Validates account state after upgrades using validator contracts that return magic values
4. **Fallback token reception**: Uses `DefaultReceiver` when no implementation is set
5. **ERC-1271 signature fallback**: Supports both implementation-based and EOA-based signature validation

### Security Features

- **Expiry-based signatures**: All implementation changes require signatures with expiry timestamps
- **Magic value validation**: Validators must return `ACCOUNT_STATE_VALIDATION_SUCCESS` constant
- **Cross-chain replay protection**: Configurable chain-specific or chain-agnostic signatures
- **External nonce tracking**: Nonces stored outside proxy to prevent storage conflicts

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
forge test --match-path test/EIP7702Proxy/setImplementation.t.sol

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

# Note: The repository includes deployment scripts but they are referenced in the README
# for specific testnet usage rather than being included in the main codebase
```

### Contract Verification
```bash
# Verify implementation contract (example for Base network)
forge verify-contract \
    --verifier blockscout \
    --verifier-url "https://base.blockscout.com/api" \
    --watch \
    --compiler-version "v0.8.23" \
    --num-of-optimizations 200 \
    <IMPLEMENTATION_ADDRESS> \
    lib/smart-wallet/src/CoinbaseSmartWallet.sol:CoinbaseSmartWallet

# Verify proxy template
forge verify-contract \
    --verifier blockscout \
    --verifier-url "https://base.blockscout.com/api" \
    --watch \
    --compiler-version "v0.8.23" \
    --num-of-optimizations 200 \
    <PROXY_ADDRESS> \
    src/EIP7702Proxy.sol:EIP7702Proxy
```

## Deployment Addresses

The contracts are deployed on all networks supported by Coinbase Smart Wallet:

- **EIP7702Proxy**: `0x7702cb554e6bFb442cb743A7dF23154544a7176C`
- **NonceTracker**: `0xD0Ff13c28679FDd75Bc09c0a430a0089bf8b95a8`  
- **DefaultReceiver**: `0x2a8010A9D71D2a5AEA19D040F8b4797789A194a9`
- **CoinbaseSmartWalletValidator**: `0x79A33f950b90C7d07E66950daedf868BD0cDcF96`

## Important Implementation Notes

### setImplementation Function Signature
The main upgrade function signature has evolved to include expiry:
```solidity
function setImplementation(
    address newImplementation,
    bytes calldata callData,
    address validator,
    uint256 expiry,
    bytes calldata signature,
    bool allowCrossChainReplay
) external
```

### Validator Interface Changes
Validators must implement the updated interface:
```solidity
function validateAccountState(address account, address implementation) external view returns (bytes4);
```
Must return `ACCOUNT_STATE_VALIDATION_SUCCESS` constant on success.

### Magic Values
- `ACCOUNT_STATE_VALIDATION_SUCCESS = 0xccd10cc8`
- `_ERC1271_MAGIC_VALUE = 0x1626ba7e`
- `_ERC1271_FAIL_VALUE = 0xffffffff`

## Security Considerations

- Contracts have been audited by Spearbit with multiple audit rounds
- All implementation changes require valid EOA signatures with expiry timestamps
- Cross-chain replay protection is configurable per operation
- External nonce tracking prevents storage slot conflicts
- Validator contracts enforce implementation-specific constraints

## Testing Strategy

The test suite covers:
- Constructor validation and edge cases
- Implementation setting with various scenarios
- Signature validation including ERC-1271 fallback
- Token delegation and reception
- State validation through mock validators
- Gas optimization and efficiency tests