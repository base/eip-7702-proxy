// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract NonceTracker {
    /// @notice Mapping of account => nonce
    mapping(address => uint256) private nonces;

    /// @notice Emitted when a nonce is used
    event NonceUsed(address indexed account, uint256 nonce);

    /// @notice Error thrown when nonce verification fails
    error InvalidNonce();

    /// @notice Error thrown when signature verification fails
    error InvalidSignature();

    /// @notice Returns the next valid nonce for an account
    /// @param account The account to get the nonce for
    /// @return The next valid nonce
    function getNextNonce(address account) external view returns (uint256) {
        return nonces[account];
    }

    /// @notice Verifies and consumes a nonce for an account
    /// @param proxyAddress The address of the proxy template
    /// @param args The initialization arguments to include in signature
    /// @param nonce The nonce to verify
    /// @param signature The signature authorizing the nonce use
    /// @return True if the nonce was valid and consumed
    function verifyAndUseNonce(
        address proxyAddress,
        bytes calldata args,
        uint256 nonce,
        bytes calldata signature
    ) external returns (bool) {
        if (nonce != nonces[msg.sender]) {
            revert InvalidNonce();
        }

        // Verify signature is from the account using the nonce
        bytes32 initHash = keccak256(abi.encode(proxyAddress, args, nonce));
        address signer = ECDSA.recover(initHash, signature);
        if (signer != msg.sender) revert InvalidSignature();

        nonces[msg.sender] = nonce + 1;
        emit NonceUsed(msg.sender, nonce);
        return true;
    }
}
