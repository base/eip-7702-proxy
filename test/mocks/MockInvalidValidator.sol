// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IAccountStateValidator} from "../../src/interfaces/IAccountStateValidator.sol";

/// @title MockInvalidValidator
/// @dev Mock validator that returns an invalid magic value for testing
contract MockInvalidValidator is IAccountStateValidator {
    function supportedImplementation() external view returns (address) {
        return address(this);
    }

    function validateAccountState(address, address) external view returns (bytes4) {
        return bytes4(keccak256("invalid()"));
    }
}
