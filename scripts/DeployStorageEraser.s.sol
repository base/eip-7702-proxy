// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MultiOwnableStorageEraser} from "../src/MultiOwnableStorageEraser.sol";

/**
 * @notice Deploy a storage eraser contract.
 *
 * forge script scripts/DeployStorageEraser.s.sol:DeployStorageEraser --account odyssey-deployer --sender $SENDER --rpc-url $ODYSSEY_RPC --broadcast -vvvv
 */
contract DeployStorageEraser is Script {
    function run() external {
        vm.startBroadcast();

        // 1. Deploy storage eraser
        MultiOwnableStorageEraser multiOwnableStorageEraser = new MultiOwnableStorageEraser();

        vm.stopBroadcast();

        // Log deployed addresses
        console.log("Deployed addresses:");
        console.log("MultiOwnableStorageEraser:", address(multiOwnableStorageEraser));
    }
}
