// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {
    IAccountStateValidator, ACCOUNT_STATE_VALIDATION_SUCCESS
} from "../../src/interfaces/IAccountStateValidator.sol";
import {MockImplementation} from "./MockImplementation.sol";

/**
 * @title MockValidator
 * @dev Mock validator that checks if the MockImplementation wallet is initialized
 */
contract MockValidator is IAccountStateValidator {
    error WalletNotInitialized();

    MockImplementation public immutable expectedImplementation;

    constructor(MockImplementation _expectedImplementation) {
        expectedImplementation = _expectedImplementation;
    }

    function supportedImplementations() external view returns (address[] memory) {
        address[] memory implementations = new address[](1);
        implementations[0] = address(expectedImplementation);
        return implementations;
    }

    /**
     * @dev Validates that the wallet is initialized
     * @param wallet Address of the wallet to validate
     * @param implementation Address of the expected implementation
     */
    function validateAccountState(address wallet, address implementation) external view returns (bytes4) {
        if (implementation != address(expectedImplementation)) {
            revert InvalidImplementation(implementation);
        }

        bool isInitialized = MockImplementation(wallet).initialized();
        if (!isInitialized) revert WalletNotInitialized();
        return ACCOUNT_STATE_VALIDATION_SUCCESS;
    }
}
