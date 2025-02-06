// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {ERC1967Utils} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";

/**
 * @title Implementation1967Resetter
 * @notice Contract deployed via EIP-7702 to reset the ERC-1967 implementation slot
 * @dev This contract is meant to be deployed temporarily at an EOA's address to reset
 *      the implementation slot before re-delegating back to the EIP7702Proxy
 */
contract Implementation1967Resetter {
    /// @notice Emitted when signature verification fails
    error InvalidSignature();

    /// @notice Emitted when nonce has already been used
    error NonceAlreadyUsed();

    /// @notice Address of the global nonce tracker contract
    address public immutable nonceTracker;

    constructor(address _nonceTracker) {
        if (_nonceTracker == address(0)) revert("Zero address");
        nonceTracker = _nonceTracker;
    }

    /**
     * @notice Resets the ERC-1967 implementation slot after signature verification
     * @param newImplementation The implementation address to set
     * @param nonce The nonce for this operation (verified against NonceTracker)
     * @param signature The EOA signature authorizing this change
     */
    function resetImplementation(
        address newImplementation,
        uint256 nonce,
        bytes calldata signature
    ) external {
        // Verify nonce hasn't been used
        if (
            !INonceTracker(nonceTracker).verifyAndUseNonce(address(this), nonce)
        ) {
            revert NonceAlreadyUsed();
        }

        // Only need to sign over the implementation and nonce
        bytes32 hash = keccak256(abi.encode(newImplementation, nonce));

        // Verify signature is from this address (the EOA)
        address recovered = ECDSA.recover(hash, signature);
        if (recovered != address(this)) {
            revert InvalidSignature();
        }

        // Update the implementation slot
        ERC1967Utils.upgradeToAndCall(
            newImplementation,
            "" // No initialization needed
        );
    }
}

/**
 * @title INonceTracker
 * @notice Interface for the nonce tracking contract
 */
interface INonceTracker {
    function verifyAndUseNonce(
        address account,
        uint256 nonce
    ) external returns (bool);
}
