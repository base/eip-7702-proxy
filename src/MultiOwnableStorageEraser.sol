// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

/// @dev Malicious contract that erases critical storage slots in MultiOwnable
/// UUPSUpgradeable will allow us to use this contract in a demo and still change the ERC1967 storage slot
contract MultiOwnableStorageEraser is UUPSUpgradeable {
    receive() external payable {}

    // Storage slot from MultiOwnable
    bytes32 private constant MULTI_OWNABLE_STORAGE_LOCATION =
        0x97e2c6aad4ce5d562ebfaa00db6b9e0fb66ea5d8162ed5b243f51a2e03086f00;

    function eraseNextOwnerIndexStorage() external {
        // Clear the nextOwnerIndex in MultiOwnableStorage
        assembly {
            // The nextOwnerIndex is the first slot in the struct
            let storageSlot := MULTI_OWNABLE_STORAGE_LOCATION
            sstore(storageSlot, 0)
        }
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override {}
}
