// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {CoinbaseSmartWallet} from "../lib/smart-wallet/src/CoinbaseSmartWallet.sol";
import {EIP7702Proxy} from "../src/EIP7702Proxy.sol";
import {NonceTracker} from "../src/NonceTracker.sol";
import {DefaultReceiver} from "../src/DefaultReceiver.sol";
import {CoinbaseSmartWalletValidator} from "../src/validators/CoinbaseSmartWalletValidator.sol";
import {MultiOwnableStorageEraser} from "../src/MultiOwnableStorageEraser.sol";

contract MultiOwnableStorageEraserTest is Test {
    uint256 constant _EOA_PRIVATE_KEY = 0xA11CE;
    address payable _eoa;

    uint256 constant _NEW_OWNER_PRIVATE_KEY = 0xB0B;
    address payable _newOwner;
    address payable _secondOwner;

    CoinbaseSmartWallet _wallet;
    CoinbaseSmartWallet _cbswImplementation;
    MultiOwnableStorageEraser _eraser;

    // core contracts
    EIP7702Proxy _proxy;
    NonceTracker _nonceTracker;
    DefaultReceiver _receiver;
    CoinbaseSmartWalletValidator _cbswValidator;

    bytes32 _IMPLEMENTATION_SET_TYPEHASH = keccak256(
        "EIP7702ProxyImplementationSet(uint256 chainId,address proxy,uint256 nonce,address currentImplementation,address newImplementation,bytes callData,address validator)"
    );

    function setUp() public {
        // Set up test accounts
        _eoa = payable(vm.addr(_EOA_PRIVATE_KEY));
        _newOwner = payable(vm.addr(_NEW_OWNER_PRIVATE_KEY));
        _secondOwner = payable(vm.addr(0xBEEF));

        // Deploy core contracts
        _cbswImplementation = new CoinbaseSmartWallet();
        _nonceTracker = new NonceTracker();
        _receiver = new DefaultReceiver();
        _cbswValidator = new CoinbaseSmartWalletValidator(_cbswImplementation);
        _eraser = new MultiOwnableStorageEraser();

        // Deploy proxy with receiver and nonce tracker
        _proxy = new EIP7702Proxy(address(_nonceTracker), address(_receiver));

        // Get the proxy's runtime code
        bytes memory proxyCode = address(_proxy).code;

        // Etch the proxy code at the target address
        vm.etch(_eoa, proxyCode);

        // Initialize the wallet with an owner
        _initializeProxy();
    }

    function test_eraseStorage() public {
        // Verify initial state
        uint256 initialNextOwnerIndex = CoinbaseSmartWallet(payable(_eoa)).nextOwnerIndex();
        assertGt(initialNextOwnerIndex, 0, "Initial nextOwnerIndex should be > 0");

        // Store proxy code for later
        bytes memory proxyCode = address(_proxy).code;

        // Get the eraser's runtime code
        bytes memory eraserCode = address(_eraser).code;

        // Etch the eraser code at the wallet's address
        vm.etch(_eoa, eraserCode);

        // Cast to eraser and call erase function
        MultiOwnableStorageEraser(_eoa).eraseNextOwnerIndexStorage();

        // Restore proxy code to allow delegatecall to work
        vm.etch(_eoa, proxyCode);

        // Verify storage was erased
        assertEq(CoinbaseSmartWallet(payable(_eoa)).nextOwnerIndex(), 0, "nextOwnerIndex should be erased to 0");

        // Evil new owner can initialize wallet
        uint256 evilNewPrivateKey = 0xBADBADBAD;
        address payable evilNewOwner = payable(vm.addr(evilNewPrivateKey));

        bytes[] memory owners = new bytes[](1);
        owners[0] = abi.encode(evilNewOwner);
        vm.prank(evilNewOwner); // prove this call can come from whoever
        CoinbaseSmartWallet(payable(_eoa)).initialize(owners);
        assertTrue(CoinbaseSmartWallet(payable(_eoa)).isOwnerAddress(evilNewOwner));
    }

    function _initializeProxy() internal {
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signSetImplementationData(_EOA_PRIVATE_KEY, initArgs);

        EIP7702Proxy(_eoa).setImplementation(
            address(_cbswImplementation),
            initArgs,
            address(_cbswValidator),
            signature,
            true // Allow cross-chain replay for tests
        );

        _wallet = CoinbaseSmartWallet(payable(_eoa));
    }

    function _createInitArgs(address owner) internal view returns (bytes memory) {
        bytes[] memory owners = new bytes[](2);
        owners[0] = abi.encode(owner);
        owners[1] = abi.encode(_secondOwner);
        bytes memory ownerArgs = abi.encode(owners);
        return abi.encodePacked(CoinbaseSmartWallet.initialize.selector, ownerArgs);
    }

    function _signSetImplementationData(uint256 signerPk, bytes memory initArgs) internal view returns (bytes memory) {
        bytes32 initHash = keccak256(
            abi.encode(
                _IMPLEMENTATION_SET_TYPEHASH,
                0, // chainId 0 for cross-chain
                _proxy,
                _nonceTracker.nonces(_eoa),
                _getERC1967Implementation(address(_eoa)),
                address(_cbswImplementation),
                keccak256(initArgs),
                address(_cbswValidator)
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, initHash);
        return abi.encodePacked(r, s, v);
    }

    function _getERC1967Implementation(address proxy) internal view returns (address) {
        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        return address(uint160(uint256(vm.load(proxy, slot))));
    }
}
