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
    /// @notice Error thrown when the implementation provided to `validateAccountState` is not the validator's expected implementation
    error InvalidImplementation(address expected, address actual);

    /// @notice Validates that an account is in a valid state
    ///
    /// @dev Should revert if account state is invalid
    ///
    /// @param account The address of the account to validate
    /// @param implementation The address of the implementation this validator expects
    function validateAccountState(address account, address implementation) external view;
}
