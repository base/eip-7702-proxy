// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @review local imports after external imports
import {NonceTracker} from "./NonceTracker.sol";

import {Proxy} from "openzeppelin-contracts/contracts/proxy/Proxy.sol";
import {ERC1967Utils} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {StorageSlot} from "openzeppelin-contracts/contracts/utils/StorageSlot.sol";

/// @title EIP7702Proxy
///
/// @notice Proxy contract designed for EIP-7702 smart accounts
///
/// @dev Implements ERC-1967 with an initial implementation address and guarded initializer function
///
/// @author Coinbase (https://github.com/base/eip-7702-proxy)
contract EIP7702Proxy is Proxy {
    /// @notice ERC1271 interface constants
    bytes4 internal constant ERC1271_MAGIC_VALUE = 0x1626ba7e;
    bytes4 internal constant ERC1271_FAIL_VALUE = 0xffffffff;

    /// @review add optional chainId
    /// @notice Typehash for initialization signatures
    bytes32 private constant INIT_TYPEHASH =
        keccak256("EIP7702ProxyInitialization(address proxy,bytes32 args,uint256 nonce)");

    /// @notice Address of this proxy contract delegate
    address immutable PROXY;

    /// @notice Initial implementation address set during construction
    address immutable INITIAL_IMPLEMENTATION;

    /// @notice Function selector on the implementation that is guarded from direct calls
    bytes4 immutable GUARDED_INITIALIZER;

    /// @notice Address of the global nonce tracker for initialization
    NonceTracker public immutable NONCE_TRACKER;

    /// @notice Emitted when the initialization signature is invalid
    error InvalidSignature();

    /// @notice Emitted when the `guardedInitializer` is called
    error InvalidInitializer();

    /// @notice Emitted when trying to delegate before initialization
    error ProxyNotInitialized();

    /// @notice Emitted when constructor arguments are zero
    error ZeroValueConstructorArguments();

    /// @notice Error when nonce verification fails
    error InvalidNonce(uint256 expected, uint256 actual);

    /// @notice Initializes the proxy with an initial implementation and guarded initializer
    ///
    /// @param implementation The initial implementation address
    /// @param initializer The selector of the `guardedInitializer` function
    /// @param nonceTracker The address of the nonce tracker contract
    constructor(address implementation, bytes4 initializer, NonceTracker nonceTracker) {
        if (implementation == address(0)) revert ZeroValueConstructorArguments();
        if (initializer == bytes4(0)) revert ZeroValueConstructorArguments();
        if (address(nonceTracker) == address(0)) revert ZeroValueConstructorArguments();

        PROXY = address(this);
        INITIAL_IMPLEMENTATION = implementation;
        GUARDED_INITIALIZER = initializer;
        NONCE_TRACKER = nonceTracker;
    }

    /// @notice Initializes the proxy and implementation with a signed payload
    ///
    /// @dev Signature must be from this contract's address
    ///
    /// @param args The initialization arguments for the implementation
    /// @param signature The signature authorizing initialization
    function initialize(bytes calldata args, bytes calldata signature) external {
        uint256 expectedNonce = NONCE_TRACKER.getNextNonce(address(this));

        /// @review add chainId
        // Construct hash using typehash to prevent signature collisions
        bytes32 initHash = keccak256(abi.encode(INIT_TYPEHASH, PROXY, keccak256(args), expectedNonce));

        // Verify signature is from the EOA
        address signer = ECDSA.recover(initHash, signature);
        if (signer != address(this)) revert InvalidSignature();

        // Verify and consume the nonce, reverts if invalid
        NONCE_TRACKER.verifyAndUseNonce(expectedNonce);

        // Initialize the implementation, reverts if initialize call fails
        ERC1967Utils.upgradeToAndCall(INITIAL_IMPLEMENTATION, abi.encodePacked(GUARDED_INITIALIZER, args));
    }

    /// @notice Handles ERC-1271 signature validation by enforcing a final `ecrecover` check if signatures fail `isValidSignature` check
    ///
    /// @dev This ensures EOA signatures are considered valid regardless of the implementation's `isValidSignature` implementation
    /// @dev When calling `isValidSignature` from the implementation contract, note that calling `this.isValidSignature` will invoke this
    ///      function and make an `ecrecover` check, whereas calling a public `isValidSignature` directly from the implementation contract will not.
    ///
    /// @param hash The hash of the message being signed
    /// @param signature The signature of the message
    ///
    /// @return The result of the `isValidSignature` check
    /// @review I think `isValidSignature` needs to be `view`?
    function isValidSignature(bytes32 hash, bytes calldata signature) external returns (bytes4) {
        // First try delegatecall to implementation
        (bool success, bytes memory result) = _implementation().delegatecall(msg.data);

        // If delegatecall succeeded and returned magic value, return that
        if (success && result.length == 32 && bytes4(result) == ERC1271_MAGIC_VALUE) {
            return ERC1271_MAGIC_VALUE;
        }

        // Try ECDSA recovery with error checking
        (address recovered, ECDSA.RecoverError error,) = ECDSA.tryRecover(hash, signature);
        // Only return success if there was no error and the signer matches
        if (error == ECDSA.RecoverError.NoError && recovered == address(this)) {
            return ERC1271_MAGIC_VALUE;
        }

        // If all checks fail, return failure value
        return ERC1271_FAIL_VALUE;
    }

    /// @inheritdoc Proxy
    /// @dev Handles ERC-1271 signature validation by enforcing an ecrecover check if signatures fail `isValidSignature` check
    /// @dev Guards a specified initializer function from being called directly
    function _fallback() internal override {
        // block guarded initializer from being called
        if (msg.sig == GUARDED_INITIALIZER) revert InvalidInitializer();

        _delegate(_implementation());
    }

    /// @notice Returns the implementation address, falling back to the initial implementation if the ERC-1967 implementation slot is not set
    ///
    /// @return The implementation address
    function _implementation() internal view override returns (address) {
        if (ERC1967Utils.getImplementation() == address(0)) {
            return INITIAL_IMPLEMENTATION;
        }
        /// @review this doubles SLOADS for happy path, can we cache implementation in memory to mitigate
        return ERC1967Utils.getImplementation();
    }

    /// @review receive after constructor for solidity style
    /// @notice Allow the account to receive ETH under any circumstances
    receive() external payable {}
}
