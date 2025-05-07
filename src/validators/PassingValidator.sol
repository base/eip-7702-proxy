// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IAccountStateValidator, ACCOUNT_STATE_VALIDATION_SUCCESS} from "../interfaces/IAccountStateValidator.sol";

/// @title PassingValidator
///
/// @notice Always passes validation
contract PassingValidator is IAccountStateValidator {
    /// @inheritdoc IAccountStateValidator
    function validateAccountState(address account, address implementation) external view override returns (bytes4) {
        return ACCOUNT_STATE_VALIDATION_SUCCESS;
    }
}
