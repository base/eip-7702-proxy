// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CoinbaseSmartWallet} from "../lib/smart-wallet/src/CoinbaseSmartWallet.sol";
import {EIP7702Proxy} from "../src/EIP7702Proxy.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * This script tests an upgraded EOA by verifying ownership and executing an ETH transfer
 *
 * Prerequisites:
 * 1. EOA must already be upgraded using UpgradeEOA.s.sol
 * 2. For local testing: Anvil node must be running with --odyssey flag
 * 3. For Odyssey testnet: Must have environment variables set:
 *    - EOA_PRIVATE_KEY: Private key of the EOA being upgraded
 *    - NEW_OWNER_PRIVATE_KEY: Private key of the account that will be the owner of the smart wallet
 *    - DEPLOYER_PRIVATE_KEY: Private key of the account that deployed the contracts (used as recipient for test transactions)
 *    - PROXY_TEMPLATE_ADDRESS_ODYSSEY: Address of the deployed proxy template on Odyssey
 *
 * Running instructions:
 *
 * Local testing:
 * ```bash
 * forge script script/Initialize.s.sol --rpc-url http://localhost:8545 --broadcast --ffi
 * ```
 *
 * Odyssey testnet:
 * ```bash
 * forge script script/Initialize.s.sol --rpc-url https://odyssey.ithaca.xyz --broadcast --ffi
 * ```
 */
contract Initialize is Script {
    // Anvil's default funded accounts (for local testing)
    address constant _ANVIL_EOA = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    uint256 constant _ANVIL_EOA_PK =
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    // Using another Anvil account as the new owner
    address constant _ANVIL_NEW_OWNER =
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    uint256 constant _ANVIL_NEW_OWNER_PK =
        0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    // Using the deployer account as recipient for test transactions
    address constant _ANVIL_DEPLOYER =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 constant _ANVIL_DEPLOYER_PK =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    // Chain IDs
    uint256 constant _ANVIL_CHAIN_ID = 31337;
    uint256 constant _ODYSSEY_CHAIN_ID = 911867;

    // Deterministic proxy address for Anvil environment
    address constant _PROXY_ADDRESS_ANVIL =
        0x2d95f129bCEbD5cF7f395c7B34106ac1DCfb0CA9;

    function run() external {
        // Determine which environment we're in
        address eoa;
        uint256 eoaPk;
        address newOwner;
        uint256 newOwnerPk;
        address deployer;
        address proxyAddr;

        if (block.chainid == _ANVIL_CHAIN_ID) {
            console.log("Using Anvil's pre-funded accounts");
            eoa = _ANVIL_EOA;
            eoaPk = _ANVIL_EOA_PK;
            newOwner = _ANVIL_NEW_OWNER;
            newOwnerPk = _ANVIL_NEW_OWNER_PK;
            deployer = _ANVIL_DEPLOYER;
            proxyAddr = _PROXY_ADDRESS_ANVIL;
        } else if (block.chainid == _ODYSSEY_CHAIN_ID) {
            console.log("Using Odyssey testnet with environment variables");
            eoaPk = vm.envUint("EOA_PRIVATE_KEY");
            eoa = vm.addr(eoaPk);
            newOwnerPk = vm.envUint("NEW_OWNER_PRIVATE_KEY");
            newOwner = vm.addr(newOwnerPk);
            uint256 deployerPk = vm.envUint("DEPLOYER_PRIVATE_KEY");
            deployer = vm.addr(deployerPk);
            proxyAddr = vm.envAddress("PROXY_TEMPLATE_ADDRESS_ODYSSEY");
        } else {
            revert("Unsupported chain ID");
        }

        console.log("EOA address:", eoa);
        console.log("New owner address:", newOwner);
        console.log("Deployer address (recipient):", deployer);
        console.log("Using proxy template at:", proxyAddr);

        // First verify the EOA has code
        require(
            address(eoa).code.length > 0,
            "EOA not upgraded yet! Run UpgradeEOA.s.sol first"
        );
        console.log("[OK] Verified EOA has been upgraded");

        // Create and sign the initialize data with just the new owner
        bytes[] memory owners = new bytes[](1);
        owners[0] = abi.encode(newOwner);
        bytes memory initArgs = abi.encode(owners);
        bytes32 initHash = keccak256(abi.encode(proxyAddr, initArgs));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(eoaPk, initHash);

        bytes memory initSignature = abi.encodePacked(r, s, v);

        // Try to recover ourselves before sending
        address recovered = ECDSA.recover(initHash, initSignature);
        console.log("Recovered:", recovered);
        require(recovered == eoa, "Signature recovery failed - wrong signer");

        // Start broadcast with EOA's private key to call initialize
        vm.startBroadcast(eoaPk);

        // Try to initialize, but handle the case where it's already initialized
        try EIP7702Proxy(payable(eoa)).initialize(initArgs, initSignature) {
            console.log("[OK] Successfully initialized the smart wallet");
        } catch Error(string memory reason) {
            console.log("[INFO] Initialize call reverted with reason:", reason);
        } catch (bytes memory) {
            console.log(
                "[INFO] Initialization failed: EOA may already have been initialized"
            );
        }

        vm.stopBroadcast();

        // Verify ownership for the new owner
        CoinbaseSmartWallet smartWallet = CoinbaseSmartWallet(payable(eoa));
        bool isNewOwner = smartWallet.isOwnerAddress(newOwner);
        require(isNewOwner, "New owner is not an owner of the smart wallet!");
        console.log("[OK] Verified new owner is the owner of the smart wallet");

        // Test that the new owner can execute a transaction
        // We'll try to send some ETH to the deployer account
        uint256 amount = 0.0001 ether;
        uint256 deployerBalanceBefore = deployer.balance;
        console.log("Deployer balance before:", deployerBalanceBefore);

        vm.startBroadcast(newOwnerPk);

        // Empty calldata for a simple ETH transfer
        bytes memory callData = "";
        smartWallet.execute(
            payable(deployer), // target: sending to the deployer
            amount, // value: amount of ETH to send
            callData // data: empty for simple ETH transfer
        );

        uint256 deployerBalanceAfter = deployer.balance;
        console.log("Deployer balance after:", deployerBalanceAfter);
        require(
            deployerBalanceAfter == deployerBalanceBefore + amount,
            "ETH transfer failed - deployer balance did not increase by the expected amount"
        );
        console.log("[OK] New owner successfully called execute");

        vm.stopBroadcast();
    }
}
