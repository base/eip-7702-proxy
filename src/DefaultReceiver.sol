// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Receiver} from "solady/accounts/Receiver.sol";

/// @title DefaultReceiver
///
/// @notice Accepts native, ERC-721, and ERC-1155 token transfers
///
/// @dev Simple inherits Solady, providing all necessary functionality:
///      - receive() for native token
///      - fallback() with receiverFallback modifier for ERC-721 and ERC-1155
///      - _useReceiverFallbackBody() returns true
///      - _beforeReceiverFallbackBody() empty implementation
///      - _afterReceiverFallbackBody() empty implementation
contract DefaultReceiver is Receiver {}
