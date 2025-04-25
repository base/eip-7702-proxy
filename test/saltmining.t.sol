// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {EIP7702Proxy} from "../src/EIP7702Proxy.sol";
import {NonceTracker} from "../src/NonceTracker.sol";
import {DefaultReceiver} from "../src/DefaultReceiver.sol";

contract SaltMiningTest is Test {
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    bytes32 constant DEPENDENCY_DEPLOYMENT_SALT = bytes32(uint256(7702));

    function testPredictDeploymentAddresses() public {
        // Get predicted addresses for our dependencies using both methods
        (address nt1, address recv1) = getPredictedDependencyAddresses();
        (address nt2, address recv2) = getPredictedDependencyAddressesAlt();

        // Verify both methods give same results
        assertEq(nt1, nt2, "NonceTracker address mismatch between prediction methods");
        assertEq(recv1, recv2, "DefaultReceiver address mismatch between prediction methods");

        // Get the proxy init code hash using these addresses
        bytes32 proxyInitCodeHash = getProxyInitCodeHash(nt1, recv1);

        console2.log("Dependency Addresses (verified by two methods):");
        console2.log("NonceTracker:", nt1);
        console2.log("DefaultReceiver:", recv1);
        console2.log("\nProxy Init Code Hash:");
        console2.logBytes32(proxyInitCodeHash);

        // Test a specific salt using both prediction methods
        bytes32 testSalt = bytes32(uint256(1));
        address proxyAddr1 = predictCreate2Address(testSalt, proxyInitCodeHash);
        address proxyAddr2 = predictCreate2AddressAlt(testSalt, proxyInitCodeHash);

        console2.log("\nProxy address predictions with salt 1:");
        console2.log("Method 1 (manual):", proxyAddr1);
        console2.log("Method 2 (vm):", proxyAddr2);
        assertEq(proxyAddr1, proxyAddr2, "Proxy address mismatch between prediction methods");
    }

    // Original method using manual CREATE2 address computation
    function getPredictedDependencyAddresses() internal pure returns (address nonceTracker, address receiver) {
        bytes32 ntInitCodeHash = keccak256(type(NonceTracker).creationCode);
        bytes32 recvInitCodeHash = keccak256(type(DefaultReceiver).creationCode);

        nonceTracker = predictCreate2Address(DEPENDENCY_DEPLOYMENT_SALT, ntInitCodeHash);
        receiver = predictCreate2Address(DEPENDENCY_DEPLOYMENT_SALT, recvInitCodeHash);
    }

    // Alternative method using Foundry's vm.computeCreate2Address
    function getPredictedDependencyAddressesAlt() internal view returns (address nonceTracker, address receiver) {
        bytes32 ntInitCodeHash = keccak256(type(NonceTracker).creationCode);
        bytes32 recvInitCodeHash = keccak256(type(DefaultReceiver).creationCode);

        nonceTracker = predictCreate2AddressAlt(DEPENDENCY_DEPLOYMENT_SALT, ntInitCodeHash);
        receiver = predictCreate2AddressAlt(DEPENDENCY_DEPLOYMENT_SALT, recvInitCodeHash);
    }

    function getProxyInitCodeHash(address nonceTracker, address receiver) internal pure returns (bytes32) {
        bytes memory creationCode = type(EIP7702Proxy).creationCode;
        bytes memory constructorArgs = abi.encode(nonceTracker, receiver);
        return keccak256(bytes.concat(creationCode, constructorArgs));
    }

    // Method 1: Manual CREATE2 address computation
    function predictCreate2Address(bytes32 salt, bytes32 initCodeHash) internal pure returns (address) {
        return
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), CREATE2_DEPLOYER, salt, initCodeHash)))));
    }

    // Method 2: Using Foundry's built-in CREATE2 address computation
    function predictCreate2AddressAlt(bytes32 salt, bytes32 initCodeHash) internal view returns (address) {
        return vm.computeCreate2Address(salt, initCodeHash, CREATE2_DEPLOYER);
    }
}
