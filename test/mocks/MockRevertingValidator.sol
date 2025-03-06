// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IAccountStateValidator} from "../../src/interfaces/IAccountStateValidator.sol";

/// @title MockRevertingValidator
/// @dev Mock validator that always reverts
contract MockRevertingValidator is IAccountStateValidator {
    error AlwaysReverts();

    function validateAccountState(address, address) external pure {
        revert AlwaysReverts();
    }
}
