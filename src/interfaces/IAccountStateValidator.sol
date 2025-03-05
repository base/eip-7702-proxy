// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title IAccountStateValidator
///
/// @notice Interface for account-specific validation logic
///
/// @dev This interface is used to validate the state of a account after an upgrade
///
/// @author Coinbase (https://github.com/base/eip-7702-proxy)
interface IAccountStateValidator {
    /// @notice Validates that a account is in a valid state
    ///
    /// @dev Should revert if account state is invalid
    ///
    /// @param account The address of the account to validate
    function validateAccountState(address account) external view;
}
