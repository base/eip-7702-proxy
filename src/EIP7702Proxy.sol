// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Proxy} from "openzeppelin-contracts/contracts/proxy/Proxy.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {StorageSlot} from "openzeppelin-contracts/contracts/utils/StorageSlot.sol";
import {CustomUpgradeable} from "./CustomUpgradeable.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

/// @title EIP7702Proxy
/// @notice Proxy contract designed for EIP-7702 smart accounts
/// @dev Implements a custom upgradeable proxy pattern with a unique storage slot
///      to avoid collisions with other delegates in an EIP-7702 context.
/// @author Coinbase (https://github.com/base-org/eip-7702-proxy)
contract EIP7702Proxy is Proxy, CustomUpgradeable {
    /// @notice ERC1271 interface constants for signature validation
    bytes4 internal constant ERC1271_MAGIC_VALUE = 0x1626ba7e;
    bytes4 internal constant ERC1271_FAIL_VALUE = 0xffffffff;

    /// @notice The address of this proxy contract
    address immutable proxy;

    /// @notice The initial implementation address
    address immutable initialImplementation;

    /// @notice The function selector that is protected from direct calls
    bytes4 immutable guardedInitializer;

    /// @dev Storage slot for the initialized flag, calculated via ERC-7201
    bytes32 internal constant INITIALIZED_SLOT =
        keccak256(
            abi.encode(uint256(keccak256("EIP7702Proxy.initialized")) - 1)
        ) & ~bytes32(uint256(0xff));

    /// @notice Emitted when a signature fails validation during initialization
    error InvalidSignature();

    /// @notice Emitted when attempting to call the guarded initializer directly
    error InvalidInitializer();

    /// @notice Emitted when trying to use the proxy before initialization
    error ProxyNotInitialized();

    /// @notice Emitted when constructor receives zero address or selector
    error ZeroValueConstructorArguments();

    /// @notice Emitted when an operation is not authorized
    error Unauthorized();

    /// @notice Initializes the proxy with an initial implementation and guarded initializer
    /// @param implementation The initial implementation address
    /// @param initializer The selector of the `guardedInitializer` function
    constructor(
        address implementation,
        bytes4 initializer
    ) CustomUpgradeable(implementation, initializer) {
        if (implementation == address(0))
            revert ZeroValueConstructorArguments();
        if (initializer == bytes4(0)) revert ZeroValueConstructorArguments();

        proxy = address(this);
        initialImplementation = implementation;
        guardedInitializer = initializer;
    }

    /// @dev Checks if proxy has been initialized by checking the initialized flag
    function _isInitialized() internal view returns (bool) {
        return StorageSlot.getBooleanSlot(INITIALIZED_SLOT).value;
    }

    /// @notice Initializes the proxy and implementation with a signed payload
    ///
    /// @dev Signature must be from this contract's address
    ///
    /// @param args The initialization arguments for the implementation
    /// @param signature The signature authorizing initialization
    function initialize(
        bytes calldata args,
        bytes calldata signature
    ) external {
        // Construct hash without Ethereum signed message prefix to prevent phishing via standard wallet signing.
        // Since this proxy is designed for EIP-7702 (where the proxy address is an EOA),
        // using a raw hash ensures that initialization signatures cannot be obtained through normal
        // wallet "Sign Message" prompts.
        bytes32 hash = keccak256(abi.encode(proxy, args));
        address recovered = ECDSA.recover(hash, signature);
        if (recovered != address(this)) revert InvalidSignature();

        // Set initialized flag before upgrading
        StorageSlot.getBooleanSlot(INITIALIZED_SLOT).value = true;

        // Update to use our custom implementation storage instead of ERC1967Utils
        _setImplementation(initialImplementation);

        (bool success, ) = initialImplementation.delegatecall(
            abi.encodePacked(guardedInitializer, args)
        );
        if (!success) {
            assembly {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }

    /// @notice Handles ERC-1271 signature validation by enforcing a final `ecrecover` check if signatures fail `isValidSignature` check
    ///
    /// @dev This ensures EOA signatures are considered valid regardless of the implementation's `isValidSignature` implementation
    ///
    /// @param hash The hash of the message being signed
    /// @param signature The signature of the message
    ///
    /// @return The result of the `isValidSignature` check
    function isValidSignature(
        bytes32 hash,
        bytes calldata signature
    ) external returns (bytes4) {
        // Check initialization status first
        if (!_isInitialized()) revert ProxyNotInitialized();

        // First try delegatecall to implementation
        (bool success, bytes memory result) = _implementation().delegatecall(
            msg.data
        );

        // If delegatecall succeeded and returned magic value, return that
        if (
            success &&
            result.length == 32 &&
            abi.decode(result, (bytes4)) == ERC1271_MAGIC_VALUE
        ) {
            return ERC1271_MAGIC_VALUE;
        }

        // Only try ECDSA if signature is the right length (65 bytes)
        if (signature.length == 65) {
            address recovered = ECDSA.recover(hash, signature);
            if (recovered == address(this)) {
                return ERC1271_MAGIC_VALUE;
            }
        }

        // If all checks fail, return failure value
        return ERC1271_FAIL_VALUE;
    }

    /// @inheritdoc Proxy
    /// @dev Handles ERC-1271 signature validation by enforcing an ecrecover check if signatures fail `isValidSignature` check
    /// @dev Guards a specified initializer function from being called directly
    function _fallback() internal override {
        if (!_isInitialized()) revert ProxyNotInitialized();

        // block guarded initializer from being called
        if (msg.sig == guardedInitializer) revert InvalidInitializer();

        _delegate(_implementation());
    }

    function _implementation() internal view override returns (address) {
        return _getImplementation();
    }

    function upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) public payable {
        // Check ownership using same logic as _checkOwner
        (bool success, bytes memory result) = _implementation().delegatecall(
            abi.encodeWithSignature("isOwnerAddress(address)", msg.sender)
        );

        if (
            !success ||
            (!abi.decode(result, (bool)) && msg.sender != address(this))
        ) {
            revert Unauthorized();
        }

        // If sender is owner or contract itself, proceed with upgrade
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);

        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }

    receive() external payable {}
}
