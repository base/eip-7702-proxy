// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @title IWalletValidator
/// @notice Interface for wallet-specific validation logic
interface IWalletValidator {
    /// @notice Validates that a wallet is in a valid state
    /// @param wallet The address of the wallet to validate
    /// @dev Should revert if wallet state is invalid
    function validateWallet(address wallet) external view;
}
