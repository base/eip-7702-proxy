// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {EIP7702Proxy} from "../src/EIP7702Proxy.sol";
import {NonceTracker} from "../src/NonceTracker.sol";
import {DefaultReceiver} from "../src/DefaultReceiver.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";
import {CoinbaseSmartWalletValidator} from "../src/validators/CoinbaseSmartWalletValidator.sol";

/**
 * @notice Deploy the EIP7702Proxy contract and its dependencies.
 *
 * @dev Before deploying contracts, make sure dependencies have been installed at the latest or otherwise specific
 * versions using `forge install [OPTIONS] [DEPENDENCIES]`.
 *
 * forge script scripts/Deploy.s.sol:Deploy --account odyssey-deployer --sender $SENDER --rpc-url $ODYSSEY_RPC --broadcast -vvvv
 */
contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        // 1. Deploy core infrastructure
        NonceTracker nonceTracker = new NonceTracker();
        DefaultReceiver receiver = new DefaultReceiver();

        // 2. Deploy implementation and validator
        CoinbaseSmartWallet implementation = new CoinbaseSmartWallet();
        CoinbaseSmartWalletValidator validator = new CoinbaseSmartWalletValidator(implementation);

        // 3. Deploy proxy factory
        EIP7702Proxy proxy = new EIP7702Proxy(address(nonceTracker), address(receiver));

        vm.stopBroadcast();

        // Log deployed addresses
        console.log("Deployed addresses:");
        console.log("NonceTracker:", address(nonceTracker));
        console.log("DefaultReceiver:", address(receiver));
        console.log("CoinbaseSmartWallet Implementation:", address(implementation));
        console.log("CoinbaseSmartWalletValidator:", address(validator));
        console.log("EIP7702Proxy:", address(proxy));
    }
}
