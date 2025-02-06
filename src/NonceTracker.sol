// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title NonceTracker
 * @notice Global nonce tracking for EIP-7702 accounts
 * @dev Maintains nonce state separately from mutable EOA storage
 */
contract NonceTracker {
    /// @notice Mapping of account => highest used nonce
    mapping(address => uint256) private highestNonce;

    /**
     * @notice Verifies and marks a nonce as used for an account
     * @param account The account using the nonce
     * @param nonce The nonce to verify and use
     * @return success True if nonce was valid and is now used
     */
    function verifyAndUseNonce(
        address account,
        uint256 nonce
    ) external returns (bool) {
        uint256 current = highestNonce[account];

        // Nonce must be strictly increasing
        if (nonce <= current) {
            return false;
        }

        highestNonce[account] = nonce;
        return true;
    }

    /**
     * @notice Gets the highest used nonce for an account
     * @param account The account to check
     * @return The highest nonce used so far
     */
    function getHighestNonce(address account) external view returns (uint256) {
        return highestNonce[account];
    }
}
