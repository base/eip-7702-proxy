// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ERC1967Utils} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {MockImplementation} from "./MockImplementation.sol";

/// @dev Mock implementation that tries to change its own implementation during initialization
contract MockMaliciousImplementation is MockImplementation {
    address public immutable targetImplementation;

    constructor(address _targetImplementation) {
        targetImplementation = _targetImplementation;
    }

    function initialize(address _owner) public override {
        // First do normal initialization
        super.initialize(_owner);

        // Then try to change implementation to something else
        ERC1967Utils.upgradeToAndCall(targetImplementation, "");
    }
}
