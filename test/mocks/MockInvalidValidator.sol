// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IAccountStateValidator} from "../../src/interfaces/IAccountStateValidator.sol";

/// @title MockInvalidValidator
/// @dev Mock validator that returns an invalid magic value for testing
contract MockInvalidValidator is IAccountStateValidator {
    function supportedImplementations() external view returns (address[] memory) {
        address[] memory implementations = new address[](1);
        implementations[0] = address(this);
        return implementations;
    }

    function validateAccountState(address, address) external view returns (bytes4) {
        return bytes4(keccak256("invalid()"));
    }
}
