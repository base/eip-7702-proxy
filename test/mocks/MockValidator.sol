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

    /**
     * @dev Validates that the wallet is initialized
     * @param wallet Address of the wallet to validate
     * @param implementation Address of the expected implementation
     */
    function validateAccountState(address wallet, address implementation) external view returns (bytes4) {
        if (implementation != address(expectedImplementation)) {
            revert InvalidImplementation(implementation);
        }

        bool isInitialized = MockImplementation(payable(wallet)).initialized();
        if (!isInitialized) revert WalletNotInitialized();
        return ACCOUNT_STATE_VALIDATION_SUCCESS;
    }
}
