// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockImplementation} from "../test/mocks/MockImplementation.sol";

/**
 * @notice Deploy a mock UUPSUpgradeable implementation contract.
 *
 * @dev Before deploying contracts, make sure dependencies have been installed at the latest or otherwise specific
 * versions using `forge install [OPTIONS] [DEPENDENCIES]`.
 *
 * forge script scripts/DeployMocks.s.sol:DeployMocks --account odyssey-deployer --sender $SENDER --rpc-url $ODYSSEY_RPC --broadcast -vvvv
 */
contract DeployMocks is Script {
    function run() external {
        vm.startBroadcast();

        // 1. Deploy mock implementation
        MockImplementation mockImplementation = new MockImplementation();

        vm.stopBroadcast();

        // Log deployed addresses
        console.log("Deployed addresses:");
        console.log("MockImplementation:", address(mockImplementation));
    }
}
