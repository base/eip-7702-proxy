// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {EIP7702ProxyBase} from "../base/EIP7702ProxyBase.sol";
import {EIP7702Proxy} from "../../src/EIP7702Proxy.sol";
import {CoinbaseSmartWallet} from "../../lib/smart-wallet/src/CoinbaseSmartWallet.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/// @review In general I think we should split our tests here between implementation-agnostic invariants the proxy maintains and separate integration tests specific to CoinbaseSmartWallet
contract IsValidSignatureTest is EIP7702ProxyBase {
    bytes4 constant ERC1271_MAGIC_VALUE = 0x1626ba7e;
    bytes4 constant ERC1271_FAIL_VALUE = 0xffffffff;

    bytes32 testHash;
    CoinbaseSmartWallet wallet;

    function setUp() public override {
        super.setUp();

        // Initialize the wallet with a contract owner
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signInitData(_EOA_PRIVATE_KEY, initArgs);
        vm.prank(_eoa);
        EIP7702Proxy(_eoa).initialize(initArgs, signature);

        wallet = CoinbaseSmartWallet(payable(_eoa));
        testHash = keccak256("test message");

        // Verify owner was set correctly
        assertTrue(wallet.isOwnerAddress(_newOwner), "New owner should be set after initialization");
        assertEq(wallet.ownerAtIndex(0), abi.encode(_newOwner), "Owner at index 0 should be new owner");
    }

    /// @review add test for calling on uninitialized contract
    /// @review add test if delegatecall reverts then bubbles up revert data

    function testValidContractOwnerSignature() public {
        // Create signature from contract owner
        bytes memory signature = _createOwnerSignature(
            testHash,
            address(wallet),
            _NEW_OWNER_PRIVATE_KEY,
            0 // First owner
        );

        bytes4 result = wallet.isValidSignature(testHash, signature);
        assertEq(result, ERC1271_MAGIC_VALUE, "Should accept valid contract owner signature");
    }

    function testValidEOASignature() public {
        // Create signature from original EOA
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_EOA_PRIVATE_KEY, testHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = wallet.isValidSignature(testHash, signature);
        assertEq(result, ERC1271_MAGIC_VALUE, "Should accept valid EOA signature");
    }

    function testInvalidEOASignature() public {
        // Create signature from wrong EOA
        uint256 wrongPk = 0xB0B;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPk, testHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = wallet.isValidSignature(testHash, signature);
        assertEq(result, ERC1271_FAIL_VALUE, "Should reject invalid EOA signature");
    }

    function testInvalidOwnerSignature() public {
        // Create a valid format signature but with wrong signer
        uint256 wrongPk = 0xBADBAD; // Different from both EOA and new owner (0xB0B)
        bytes memory signature = _createOwnerSignature(testHash, address(wallet), wrongPk, 0);

        bytes4 result = wallet.isValidSignature(testHash, signature);
        assertEq(result, ERC1271_FAIL_VALUE, "Should reject signature from non-owner");
    }

    function testEmptySignature() public {
        bytes memory emptySignature = "";

        bytes4 result = wallet.isValidSignature(testHash, emptySignature);
        assertEq(result, ERC1271_FAIL_VALUE, "Should reject empty signature");
    }
}
