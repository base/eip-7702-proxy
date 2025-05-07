// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PassingValidator} from "../src/validators/PassingValidator.sol";

/**
 * @notice Deploy a passing validator contract.
 *
 * forge script scripts/DeployPassingValidator.s.sol:DeployPassingValidator --account odyssey-deployer --sender $SENDER --rpc-url $ODYSSEY_RPC --broadcast -vvvv
 */
contract DeployPassingValidator is Script {
    function run() external {
        vm.startBroadcast();

        // 1. Deploy passing validator
        PassingValidator passingValidator = new PassingValidator();

        vm.stopBroadcast();

        // Log deployed addresses
        console.log("Deployed addresses:");
        console.log("PassingValidator:", address(passingValidator));
    }
}
