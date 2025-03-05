// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IAccountStateValidator} from "../../src/interfaces/IAccountStateValidator.sol";
import {MockImplementation} from "./MockImplementation.sol";

/// @title MockRevertingValidator
/// @dev Mock validator that always reverts
contract MockRevertingValidator is IAccountStateValidator {
    error AlwaysReverts();

    function validateAccountState(address) external pure {
        revert AlwaysReverts();
    }
}
