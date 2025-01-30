// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {EIP7702ProxyBase} from "../base/EIP7702ProxyBase.sol";
import {EIP7702Proxy} from "../../src/EIP7702Proxy.sol";
import {CoinbaseSmartWallet} from "../../lib/smart-wallet/src/CoinbaseSmartWallet.sol";

/// @review In general I think we should split our tests here between implementation-agnostic invariants the proxy maintains and separate integration tests specific to CoinbaseSmartWallet
contract DelegateTest is EIP7702ProxyBase {
    function setUp() public override {
        super.setUp();

        // Initialize the proxy for delegation tests
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signInitData(_EOA_PRIVATE_KEY, initArgs);
        vm.prank(_eoa);
        EIP7702Proxy(_eoa).initialize(initArgs, signature);
    }

    /// @review prefer fuzzing where possible
    function testBlocksGuardedInitializer() public {
        bytes memory initData =
            abi.encodeWithSelector(CoinbaseSmartWallet.initialize.selector, _createInitArgs(_newOwner));

        vm.expectRevert(EIP7702Proxy.InvalidInitializer.selector);
        address(_eoa).call(initData);
    }

    /// @review add test for non-binary return data, e.g. ownerAtIndex
    /// @review add test for if read fails, then delegate fails
    /// @review add test for if implementation slot is empty
    function testDelegatesReadCall() public {
        assertTrue(CoinbaseSmartWallet(payable(_eoa)).isOwnerAddress(_newOwner), "Delegated read call should succeed");
    }

    /// @review prefer fuzzing where possible
    /// @review add test for if write fails, then delegate fails
    /// @review add test for if implementation slot is empty
    function testDelegatesWriteCall() public {
        // Test a state-changing call
        address recipient = address(0xBEEF);
        uint256 amount = 1 ether;

        // Fund the proxy
        vm.deal(address(_eoa), amount);

        vm.prank(_newOwner);
        CoinbaseSmartWallet(payable(_eoa)).execute(
            payable(recipient),
            amount,
            "" // empty calldata for simple transfer
        );

        assertEq(recipient.balance, amount, "Delegated write call should transfer ETH");
    }
}
