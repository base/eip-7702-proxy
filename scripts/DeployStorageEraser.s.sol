// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MultiOwnableStorageEraser} from "../src/MultiOwnableStorageEraser.sol";

/**
 * @notice Deploy a storage eraser contract.
 *
 * forge script scripts/DeployStorageEraser.s.sol:DeployStorageEraser --account spmdeployer --sender $SPM_DEPLOYER --rpc-url $BASE_SEPOLIA_RPC --broadcast -vvvv --verify --verifier-url $SEPOLIA_BASESCAN_API --etherscan-api-key $BASESCAN_API_KEY
 * forge script scripts/DeployStorageEraser.s.sol:DeployStorageEraser --account spmdeployer --sender $SPM_DEPLOYER --rpc-url $BASE_RPC --broadcast -vvvv --verify --verifier-url $BASESCAN_API --etherscan-api-key $BASESCAN_API_KEY
 * forge verify-contract --chain-id 84532 --num-of-optimizations 20000 --watch --etherscan-api-key $BASESCAN_API_KEY --compiler-version v0.8.23 0xf88cBE56c3b636747AD8FF21890A6B96954eE5E8 MultiOwnableStorageEraser --verifier-url $SEPOLIA_BASESCAN_API
 */
contract DeployStorageEraser is Script {
    uint256 constant SALT = 1;

    function run() external {
        vm.startBroadcast();

        // 1. Deploy storage eraser
        MultiOwnableStorageEraser multiOwnableStorageEraser =
            new MultiOwnableStorageEraser{salt: bytes32(uint256(SALT))}();

        vm.stopBroadcast();

        // Log deployed addresses
        console.log("Deployed addresses:");
        console.log("MultiOwnableStorageEraser:", address(multiOwnableStorageEraser)); // 0xf88cBE56c3b636747AD8FF21890A6B96954eE5E8 and has been deployed on Base and Base Sepolia
    }
}
