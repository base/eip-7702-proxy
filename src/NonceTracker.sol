// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @title NonceTracker
///
/// @notice A separate storage contract for securely tracking nonces for EIP-7702 proxies.
///
/// @dev This contract is used to track nonces for EIP-7702 proxies. It is separate from the storage location
///      of the 7702 account itself to prevent the nonce from being tampered with by other arbitrary delegates
///      of the account.
///
/// @author Coinbase (https://github.com/base/eip-7702-proxy)
contract NonceTracker {
    /// @notice Mapping of account => nonce
    mapping(address => uint256) private _nonces;

    /// @notice Emitted when a nonce is used
    event NonceUsed(address indexed account, uint256 nonce);

    /// @notice Error when nonce is invalid
    error InvalidNonce(uint256 expected, uint256 actual);

    /// @notice Get the next expected nonce for an account
    function getNextNonce(address account) external view returns (uint256) {
        return _nonces[account];
    }

    /// @notice Verify and consume a nonce for the caller
    ///
    /// @dev Reverts if nonce doesn't match the next expected value
    ///
    /// @param nonce The nonce to verify
    ///
    /// @return true if nonce was valid and consumed
    function verifyAndUseNonce(uint256 nonce) external returns (bool) {
        if (nonce != _nonces[msg.sender]) revert InvalidNonce(_nonces[msg.sender], nonce);

        _nonces[msg.sender] = nonce + 1;
        emit NonceUsed(msg.sender, nonce);
        /// @review do we need a return if we're not using it and this reverts on failure anyways?
        return true;
    }
}
