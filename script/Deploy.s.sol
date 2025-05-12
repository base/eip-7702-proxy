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

        // CoinbaseSmartWalletValidator coinbaseSmartWalletValidator =
        //     CoinbaseSmartWalletValidator(0x79A33f950b90C7d07E66950daedf868BD0cDcF96);
        // NonceTracker nonceTracker = NonceTracker(0xD0Ff13c28679FDd75Bc09c0a430a0089bf8b95a8);
        // DefaultReceiver defaultReceiver = DefaultReceiver(payable(0x2a8010A9D71D2a5AEA19D040F8b4797789A194a9));

        EIP7702Proxy proxy = new EIP7702Proxy{salt: PROXY_DEPLOYMENT_SALT}({
            nonceTracker_: address(nonceTracker),
            receiver: address(defaultReceiver)
        });

        logAddress("CoinbaseSmartWalletValidator", address(coinbaseSmartWalletValidator)); // 0x79A33f950b90C7d07E66950daedf868BD0cDcF96
        logAddress("NonceTracker", address(nonceTracker)); // 0xD0Ff13c28679FDd75Bc09c0a430a0089bf8b95a8
        logAddress("DefaultReceiver", address(defaultReceiver)); // 0x2a8010A9D71D2a5AEA19D040F8b4797789A194a9
        logAddress("EIP7702Proxy", address(proxy)); // 0x7702cb554e6bFb442cb743A7dF23154544a7176C
    }

    function logAddress(string memory name, address addr) internal pure {
        console2.logString(string.concat(name, ": ", Strings.toHexString(addr)));
    }
}
