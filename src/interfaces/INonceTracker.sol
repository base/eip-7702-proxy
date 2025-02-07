// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface INonceTracker {
    function getNextNonce(address account) external view returns (uint256);

    function verifyAndUseNonce(
        address account,
        uint256 nonce
    ) external returns (bool);
}
