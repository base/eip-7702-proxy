// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {CoinbaseSmartWallet} from "smart-wallet/CoinbaseSmartWallet.sol";

import {CoinbaseSmartWalletValidator} from "../src/validators/CoinbaseSmartWalletValidator.sol";
import {NonceTracker} from "../src/NonceTracker.sol";
import {DefaultReceiver} from "../src/DefaultReceiver.sol";
import {EIP7702Proxy} from "../src/EIP7702Proxy.sol";

/**
 * @notice Deploy the `EIP7702Proxy` contract and its dependencies.
 *
 * @dev Before deploying contracts, make sure dependencies have been installed at the latest or otherwise specific
 * versions using `forge install [OPTIONS] [DEPENDENCIES]`.
 *
 * forge script Deploy --account dev --sender $SENDER --rpc-url $BASE_SEPOLIA_RPC --verify --verifier-url
 * $SEPOLIA_BASESCAN_API --etherscan-api-key $BASESCAN_API_KEY --broadcast -vvvv
 */
contract Deploy is Script {
    CoinbaseSmartWallet constant COINBASE_SMART_WALLET_IMPLEMENTATION =
        CoinbaseSmartWallet(payable(0x000100abaad02f1cfC8Bbe32bD5a564817339E72));
    bytes32 constant DEPENDENCY_DEPLOYMENT_SALT = bytes32(uint256(7702));
    bytes32 constant PROXY_DEPLOYMENT_SALT = bytes32(uint256(23662924));

    function run() public {
        vm.startBroadcast();

        deploy();

        vm.stopBroadcast();
    }

    function deploy() internal {
        CoinbaseSmartWalletValidator coinbaseSmartWalletValidator =
            new CoinbaseSmartWalletValidator{salt: DEPENDENCY_DEPLOYMENT_SALT}(COINBASE_SMART_WALLET_IMPLEMENTATION);
        NonceTracker nonceTracker = new NonceTracker{salt: DEPENDENCY_DEPLOYMENT_SALT}();
        DefaultReceiver defaultReceiver = new DefaultReceiver{salt: DEPENDENCY_DEPLOYMENT_SALT}();
        EIP7702Proxy proxy = new EIP7702Proxy{salt: PROXY_DEPLOYMENT_SALT}({
            nonceTracker_: address(nonceTracker),
            receiver: address(defaultReceiver)
        });

        logAddress("CoinbaseSmartWalletValidator", address(coinbaseSmartWalletValidator));
        logAddress("NonceTracker", address(nonceTracker));
        logAddress("DefaultReceiver", address(defaultReceiver));
        logAddress("EIP7702Proxy", address(proxy));
    }

    function logAddress(string memory name, address addr) internal pure {
        console2.logString(string.concat(name, ": ", Strings.toHexString(addr)));
    }
}
