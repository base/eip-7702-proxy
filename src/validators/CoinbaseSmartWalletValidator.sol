// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MultiOwnable} from "smart-wallet/MultiOwnable.sol";

import {IAccountStateValidator} from "../interfaces/IAccountStateValidator.sol";

/// @title CoinbaseSmartWalletValidator
///
/// @notice Validates account state against invariants specific to CoinbaseSmartWallet
contract CoinbaseSmartWalletValidator is IAccountStateValidator {
    /// @notice Error thrown when an account has no nextOwnerIndex
    error Unintialized();

    /// @inheritdoc IAccountStateValidator
    ///
    /// @dev Mimics the exact logic used in `CoinbaseSmartWallet.initialize` for consistency
    function validateAccountState(address account) external view override {
        if (MultiOwnable(account).nextOwnerIndex() == 0) revert Unintialized();
    }
}
