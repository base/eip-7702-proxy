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
 * forge script scripts/DeployMocks.s.sol:DeployMocks --account spmdeployer --sender $SPM_DEPLOYER --rpc-url $BASE_SEPOLIA_RPC --broadcast -vvvv --verify --verifier-url $SEPOLIA_BASESCAN_API --etherscan-api-key $BASESCAN_API_KEY
 * forge script scripts/DeployMocks.s.sol:DeployMocks --account spmdeployer --sender $SPM_DEPLOYER --rpc-url $BASE_RPC --broadcast -vvvv --verify --verifier-url $BASESCAN_API --etherscan-api-key $BASESCAN_API_KEY
 */
contract DeployMocks is Script {
    uint256 constant SALT = 1;

    function run() external {
        vm.startBroadcast();

        // 1. Deploy mock implementation
        MockImplementation mockImplementation = new MockImplementation{salt: bytes32(uint256(SALT))}();

        vm.stopBroadcast();

        // Log deployed addresses
        console.log("Deployed addresses:");
        console.log("MockImplementation:", address(mockImplementation)); //0x011056384Cb0C3F6B999A65d9f664a835961FFe3 and has been deployed on Base and Base Sepolia
    }
}
