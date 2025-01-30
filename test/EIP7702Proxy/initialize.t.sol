// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {EIP7702ProxyBase} from "../base/EIP7702ProxyBase.sol";
import {EIP7702Proxy} from "../../src/EIP7702Proxy.sol";
import {CoinbaseSmartWallet} from "../../lib/smart-wallet/src/CoinbaseSmartWallet.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {ERC1967Utils} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";

/// @review In general I think we should split our tests here between implementation-agnostic invariants the proxy maintains and separate integration tests specific to CoinbaseSmartWallet
contract InitializeTest is EIP7702ProxyBase {
    /// @review style should be snake_case, e.g. test_success_validSignature
    /// @review prefer fuzzing where possible
    /// @review add test where fails because initializer delegatecall fails
    function testSucceedsWithValidSignature() public {
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signInitData(_EOA_PRIVATE_KEY, initArgs);

        EIP7702Proxy(_eoa).initialize(initArgs, signature);

        // Verify initialization through implementation at the EOA's address
        CoinbaseSmartWallet wallet = CoinbaseSmartWallet(payable(_eoa));
        assertTrue(wallet.isOwnerAddress(_newOwner), "New owner should be owner after initialization");
    }

    /// @review style should be snake_case
    function testRevertsWithInvalidSignature() public {
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = hex"deadbeef"; // Invalid signature

        vm.expectRevert(); // Should revert with signature verification error
        EIP7702Proxy(_eoa).initialize(initArgs, signature);
    }

    /// @review prefer fuzzing where possible
    /// @review add more tests like this for replay protection cases (same sig, different proxy or args)
    function testRevertsWithWrongSigner() public {
        // Create signature with different private key
        uint256 wrongPk = 0xC0FFEE; // Using a different key than either EOA or new owner

        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes32 initHash = keccak256(abi.encode(_eoa, initArgs));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPk, initHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(); // Should revert with signature verification error
        EIP7702Proxy(_eoa).initialize(initArgs, signature);
    }

    /// @review prefer fuzzing where possible
    /// @review this is specific to the implementation, would prefer to segment into an integration test suite with CoinbaseSmartWallet
    function testCanOnlyBeCalledOnce() public {
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signInitData(_EOA_PRIVATE_KEY, initArgs);

        EIP7702Proxy(_eoa).initialize(initArgs, signature);

        // Try to initialize again
        vm.expectRevert(CoinbaseSmartWallet.Initialized.selector);
        EIP7702Proxy(_eoa).initialize(initArgs, signature);
    }

    /// @review prefer fuzzing where possible
    /// @review think we should have a test that mocks users having the 1967 slot already set to another implementation.
    ///         For example they delegate to something metamask sets up and then move over the CBSW. How does our contract behave in these scenarios?
    /// @review add test for if implementation slot has been changed to non-original value
    function testSetsERC1967ImplementationSlot() public {
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signInitData(_EOA_PRIVATE_KEY, initArgs);

        EIP7702Proxy(_eoa).initialize(initArgs, signature);

        address storedImpl = _getERC1967Implementation(address(_eoa));
        assertEq(
            storedImpl, address(_implementation), "ERC1967 implementation slot should store implementation address"
        );
    }

    function testEmitsUpgradedEvent() public {
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signInitData(_EOA_PRIVATE_KEY, initArgs);

        vm.expectEmit(true, false, false, false, address(_eoa));
        emit EIP7702Proxy.Upgraded(address(_implementation));
        EIP7702Proxy(_eoa).initialize(initArgs, signature);
    }
}
