// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MultiOwnable} from "smart-wallet/MultiOwnable.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";
import {IAccountStateValidator} from "../interfaces/IAccountStateValidator.sol";

/// @title CoinbaseSmartWalletValidator
///
/// @notice Validates account state against invariants specific to CoinbaseSmartWallet
contract CoinbaseSmartWalletValidator is IAccountStateValidator {
    /// @notice Error thrown when an account has no nextOwnerIndex
    error Unintialized();

    /// @notice The implementation of the CoinbaseSmartWallet this validator expects
    CoinbaseSmartWallet public immutable walletImplementation;

    constructor(CoinbaseSmartWallet _walletImplementation) {
        walletImplementation = _walletImplementation;
    }

    /// @inheritdoc IAccountStateValidator
    ///
    /// @dev Mimics the exact logic used in `CoinbaseSmartWallet.initialize` for consistency
    function validateAccountState(address account, address implementation) external view override {
        if (implementation != address(walletImplementation)) {
            revert InvalidImplementation(address(walletImplementation), implementation);
        }
        if (MultiOwnable(account).nextOwnerIndex() == 0) revert Unintialized();
    }
}
