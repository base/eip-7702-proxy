// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @dev Magic value returned by validateAccountState on success
bytes4 constant ACCOUNT_STATE_VALIDATION_SUCCESS = 0x61014884; // bytes4(keccak256("validateAccountState(address,address)"))

/// @title IAccountStateValidator
/// @notice Interface for account-specific validation logi
/// @dev This interface is used to validate the state of a account after an upgrade
/// @author Coinbase (https://github.com/base/eip-7702-proxy)
interface IAccountStateValidator {
    /// @notice Error thrown when the implementation provided to `validateAccountState` is not a supported implementation
    error InvalidImplementation(address actual);

    /// @notice Returns an array of implementations this validator is capable of validating
    function supportedImplementations() external view returns (address[] memory);

    /// @notice Validates that an account is in a valid state
    /// @dev Should return ACCOUNT_STATE_VALIDATION_SUCCESS if account state is valid, otherwise revert
    /// @dev Should validate that the provided implementation is a supported implementation for this validator
    /// @param account The address of the account to validate
    /// @param implementation The address of the implementation being validated
    /// @return The magic value ACCOUNT_STATE_VALIDATION_SUCCESS if validation succeeds
    function validateAccountState(address account, address implementation) external view returns (bytes4);
}
