// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MultiOwnable} from "smart-wallet/MultiOwnable.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";
import {IAccountStateValidator, ACCOUNT_STATE_VALIDATION_SUCCESS} from "../interfaces/IAccountStateValidator.sol";

/// @title CoinbaseSmartWalletValidator
///
/// @notice Validates account state against invariants specific to CoinbaseSmartWallet
contract CoinbaseSmartWalletValidator is IAccountStateValidator {
    /// @notice Error thrown when an account's nextOwnerIndex is 0
    error Unintialized();

    /// @notice The implementation of the CoinbaseSmartWallet this validator expects
    CoinbaseSmartWallet internal immutable _supportedImplementation;

    constructor(CoinbaseSmartWallet supportedImplementation) {
        _supportedImplementation = supportedImplementation;
    }

    /// @inheritdoc IAccountStateValidator
    ///
    /// @dev Mimics the exact logic used in `CoinbaseSmartWallet.initialize` for consistency
    function validateAccountState(address account, address implementation) external view override returns (bytes4) {
        if (implementation != address(_supportedImplementation)) {
            revert InvalidImplementation(implementation);
        }
        if (MultiOwnable(account).nextOwnerIndex() == 0) revert Unintialized();
        return ACCOUNT_STATE_VALIDATION_SUCCESS;
    }
}
