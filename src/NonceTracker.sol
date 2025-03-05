// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title NonceTracker
///
/// @notice A singleton contract for EIP-7702 accounts to manage nonces for ERC-1967 implementation overrides
///
/// @dev Separating nonce storage from EIP-7702 accounts mitigates other arbitrary delegates from unexpectedly reversing state
///
/// @author Coinbase (https://github.com/base/eip-7702-proxy)
contract NonceTracker {
    /// @notice Track nonces per-account to mitigate signature replayability
    mapping(address account => uint256 nonce) public nonces;

    /// @notice An account's nonce has been used
    event NonceUsed(address indexed account, uint256 nonce);

    /// @notice Consume a nonce for the caller
    ///
    /// @return nonce The nonce just used
    function useNonce() external returns (uint256 nonce) {
        nonce = nonces[msg.sender]++;
        emit NonceUsed(msg.sender, nonce);
    }
}
