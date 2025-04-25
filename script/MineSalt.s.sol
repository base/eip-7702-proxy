// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import {LibString} from "solady/utils/LibString.sol";
import {EIP7702Proxy} from "../src/EIP7702Proxy.sol";
import {NonceTracker} from "../src/NonceTracker.sol";
import {DefaultReceiver} from "../src/DefaultReceiver.sol";

contract MineSaltScript is Script, StdAssertions {
    using LibString for bytes;

    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    bytes32 constant DEPENDENCY_DEPLOYMENT_SALT = bytes32(uint256(7702));

    // Define desired prefixes right in the contract
    // string[] prefixesToTry = ["432e"]; // proof that a matching one works
    string[] prefixesToTry = ["cb7702", "e147702", "7702cb"];

    function getProxyInitCodeHash() internal pure returns (bytes32) {
        // First get predicted addresses for dependencies
        bytes32 ntInitCodeHash = keccak256(type(NonceTracker).creationCode);
        bytes32 recvInitCodeHash = keccak256(type(DefaultReceiver).creationCode);

        // Predict their addresses based on our fixed salt
        address predictedNonceTracker = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(bytes1(0xff), CREATE2_DEPLOYER, DEPENDENCY_DEPLOYMENT_SALT, ntInitCodeHash)
                    )
                )
            )
        );

        address predictedReceiver = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(bytes1(0xff), CREATE2_DEPLOYER, DEPENDENCY_DEPLOYMENT_SALT, recvInitCodeHash)
                    )
                )
            )
        );

        // Get the proxy's init code hash with these predicted addresses
        bytes memory creationCode = type(EIP7702Proxy).creationCode;
        bytes memory constructorArgs = abi.encode(predictedNonceTracker, predictedReceiver);
        return keccak256(bytes.concat(creationCode, constructorArgs));
    }

    function tryMineSaltRange(uint256 startSalt, uint256 batchSize)
        public
        returns (bytes32 salt, address addr, bool found)
    {
        bytes32 initCodeHash = getProxyInitCodeHash();

        for (uint256 i = startSalt; i < startSalt + batchSize; i++) {
            bytes32 currentSalt = bytes32(i);
            address predictedAddr = vm.computeCreate2Address(currentSalt, initCodeHash, CREATE2_DEPLOYER);
            string memory addrStr = LibString.toHexString(uint160(predictedAddr));

            for (uint256 j = 0; j < prefixesToTry.length; j++) {
                if (hasPrefix(addrStr, prefixesToTry[j])) {
                    return (currentSalt, predictedAddr, true);
                }
            }
        }
        return (bytes32(0), address(0), false);
    }

    function hasPrefix(string memory addr, string memory prefix) internal pure returns (bool) {
        // Remove "0x" prefix from address and convert to string
        string memory addrNoPrefix = LibString.slice(addr, 2, bytes(addr).length);

        // Check for prefix with any number of leading zeros
        uint256 prefixLen = bytes(prefix).length;
        uint256 addrLen = bytes(addrNoPrefix).length;

        for (uint256 i = 0; i <= addrLen - prefixLen; i++) {
            // Check if all characters before this position are '0'
            bool allZeros = true;
            for (uint256 j = 0; j < i; j++) {
                if (bytes(addrNoPrefix)[j] != bytes1("0")) {
                    allZeros = false;
                    break;
                }
            }

            if (!allZeros) continue;

            // Check if prefix matches at this position
            bool matches = true;
            for (uint256 j = 0; j < prefixLen; j++) {
                if (bytes(addrNoPrefix)[i + j] != bytes(prefix)[j]) {
                    matches = false;
                    break;
                }
            }

            if (matches) return true;
        }
        return false;
    }

    function run() public {
        // Get salt range from environment
        uint256 startSalt = vm.envOr("SALT_START", uint256(0));
        uint256 batchSize = vm.envOr("SALT_BATCH", uint256(1000000));

        console2.log("Mining salts from", startSalt, "to", startSalt + batchSize);

        (bytes32 salt, address addr, bool found) = tryMineSaltRange(startSalt, batchSize);

        if (found) {
            console2.log("FOUND! Salt:", uint256(salt), "Address:", addr);
            require(true, "FOUND_MATCH");
        } else {
            revert("NO_MATCH_FOUND");
        }
    }
}
