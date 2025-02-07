// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

contract NonceTracker {
    /// @notice Mapping of account => nonce
    mapping(address => uint256) private nonces;

    /// @notice Emitted when a nonce is used
    event NonceUsed(address indexed account, uint256 nonce);

    /// @notice Error when nonce is invalid
    error InvalidNonce();

    /// @notice Get the next expected nonce for an account
    function getNextNonce(address account) external view returns (uint256) {
        return nonces[account];
    }

    /// @notice Verify and consume a nonce for an account
    /// @dev Reverts if nonce doesn't match the next expected value
    /// @param account The account to verify nonce for
    /// @param nonce The nonce to verify
    /// @return true if nonce was valid and consumed
    function verifyAndUseNonce(
        address account,
        uint256 nonce
    ) external returns (bool) {
        if (nonce != nonces[account]) revert InvalidNonce();

        nonces[account] = nonce + 1;
        emit NonceUsed(account, nonce);
        return true;
    }
}
