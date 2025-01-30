// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @review does Solady v0.1 have something equivalent offerings for these depedencies? would be nice to use what we recently paid to audit and would probably also be optimized
import {Proxy} from "openzeppelin-contracts/contracts/proxy/Proxy.sol";
import {ERC1967Utils} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

/// @title EIP7702Proxy
/// @notice Proxy contract designed for EIP-7702 smart accounts.
/// @dev Implements ERC-1967 with an initial implementation and guarded initialization.
/// @author Coinbase (https://github.com/base-org/eip-7702-proxy).
contract EIP7702Proxy is Proxy {
    /// @notice ERC1271 interface constants
    bytes4 internal constant ERC1271_MAGIC_VALUE = 0x1626ba7e;
    bytes4 internal constant ERC1271_FAIL_VALUE = 0xffffffff;

    /// @notice Address of this proxy contract (stored as immutable)
    address immutable proxy;

    /// @notice Initial implementation address set during construction
    address immutable initialImplementation;

    /// @notice Function selector on the implementation that is guarded from direct calls
    bytes4 immutable guardedInitializer;

    /// @review natspec
    event Upgraded(address indexed implementation);

    /// @review natspec
    error InvalidSignature();

    /// @review natspec
    error InvalidInitializer();

    /// @review natspec
    error InvalidImplementation();

    /// @review natspec
    constructor(address implementation, bytes4 initializer) {
        proxy = address(this);
        initialImplementation = implementation;
        /// @review what happens if `initializer` is one of the selectors we define in this contract?
        guardedInitializer = initializer;
    }

    /// @notice Initializes the proxy and implementation with a signed payload
    ///
    /// @param args The initialization arguments for the implementation
    /// @param signature The signature authorizing initialization
    ///
    /// @dev Signature must be from this contract's address
    function initialize(bytes calldata args, bytes calldata signature) external {
        // construct hash incompatible with wallet RPCs to avoid phishing
        bytes32 hash = keccak256(abi.encode(proxy, args));
        address recovered = ECDSA.recover(hash, signature);
        if (recovered != address(this)) revert InvalidSignature();

        // enforce initialization only on initial implementation
        address implementation = _implementation();
        if (implementation != initialImplementation) revert InvalidImplementation();

        // Set the ERC-1967 implementation slot and emit Upgraded event
        ERC1967Utils.upgradeToAndCall(initialImplementation, "");
        /// @review we can just put the initializer calldata into the second arg of `upgradeToAndCall` above correct?
        Address.functionDelegateCall(initialImplementation, abi.encodePacked(guardedInitializer, args));
    }

    /// @review let's use consistent comment format `///`, wdyt?
    /**
     * @notice Handles ERC-1271 signature validation by enforcing a final ecrecover check if signatures fail `isValidSignature` check
     *
     * @dev This ensures EOA signatures are considered valid regardless of the implementation's `isValidSignature` implementation
     *
     * @param hash The hash of the message being signed
     * @param signature The signature of the message
     *
     * @return The result of the `isValidSignature` check
     */
    function isValidSignature(bytes32 hash, bytes calldata signature) external returns (bytes4) {
        // First try delegatecall to implementation
        (bool success, bytes memory result) = _implementation().delegatecall(msg.data);

        // If delegatecall succeeded and returned magic value, return that
        if (success && result.length == 32 && abi.decode(result, (bytes4)) == ERC1271_MAGIC_VALUE) {
            /// @review this selective use of assembly reads kind of funny lol, how much gas are we saving here?
            assembly {
                mstore(0, ERC1271_MAGIC_VALUE)
                return(0, 32)
            }
        }

        // Only try ECDSA if signature is the right length (65 bytes)
        if (signature.length == 65) {
            address recovered = ECDSA.recover(hash, signature);
            if (recovered == address(this)) {
                assembly {
                    mstore(0, ERC1271_MAGIC_VALUE)
                    return(0, 32)
                }
            }
        }

        // If all checks fail, return failure value
        assembly {
            mstore(0, ERC1271_FAIL_VALUE)
            return(0, 32)
        }
    }

    /// @review Do we need to override this now that we are setting the implementation at initialization?
    /// @inheritdoc Proxy
    function _implementation() internal view override returns (address) {
        address implementation = ERC1967Utils.getImplementation();
        return implementation != address(0) ? implementation : initialImplementation;
    }

    /// @inheritdoc Proxy
    /// @dev Handles ERC-1271 signature validation by enforcing an ecrecover check if signatures fail `isValidSignature` check
    /// @dev Guards a specified initializer function from being called directly
    function _fallback() internal override {
        // block guarded initializer from being called
        if (msg.sig == guardedInitializer) revert InvalidInitializer();

        /// @review should we prevent all delegate calls if the implementation is not yet initialized? Feels like a good default protection
        _delegate(_implementation());
    }
}
