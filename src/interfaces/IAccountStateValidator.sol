// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @dev Magic value returned by validateAccountState on success
bytes4 constant VALIDATION_SUCCESS = 0x61014884; // bytes4(keccak256("validateAccountState(address,address)"))

/// @title IAccountStateValidator
/// @notice Interface for account-specific validation logi
/// @dev This interface is used to validate the state of a account after an upgrade
/// @author Coinbase (https://github.com/base/eip-7702-proxy)
interface IAccountStateValidator {
    /// @notice Error thrown when the implementation provided to `validateAccountState` is not the validator's expected implementation
    error InvalidImplementation(address expected, address actual);

    /// @notice Validates that an account is in a valid state
    ///
    /// @dev Should return VALIDATION_SUCCESS if account state is valid, otherwise revert
    ///
    /// @param account The address of the account to validate
    /// @param implementation The address of the implementation this validator expects
    /// @return The magic value VALIDATION_SUCCESS if validation succeeds
    function validateAccountState(address account, address implementation) external view returns (bytes4);
}
