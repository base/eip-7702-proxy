// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {EIP7702ProxyBase} from "../base/EIP7702ProxyBase.sol";
import {EIP7702Proxy} from "../../src/EIP7702Proxy.sol";
import {MockImplementation} from "../mocks/MockImplementation.sol";

contract DelegateTest is EIP7702ProxyBase {
    bytes4 constant INITIALIZER = MockImplementation.initialize.selector;

    function setUp() public override {
        super.setUp();

        // Initialize the proxy
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signInitData(_EOA_PRIVATE_KEY, initArgs);
        EIP7702Proxy(_eoa).initialize(initArgs, signature);
    }

    function test_succeeds_whenReadingState() public {
        assertEq(
            MockImplementation(payable(_eoa)).owner(),
            _newOwner,
            "Delegated read call should succeed"
        );
    }

    function test_succeeds_whenWritingState() public {
        vm.prank(_newOwner);
        MockImplementation(payable(_eoa)).mockFunction();
    }

    function test_preservesReturnData_whenReturningBytes(
        bytes memory testData
    ) public {
        bytes memory returnedData = MockImplementation(payable(_eoa))
            .returnBytesData(testData);

        assertEq(
            returnedData,
            testData,
            "Complex return data should be correctly delegated"
        );
    }

    function test_guardedInitializer_reverts_whenCalledDirectly(
        bytes memory initData
    ) public {
        vm.assume(initData.length >= 4); // At least a function selector

        vm.expectRevert(EIP7702Proxy.InvalidInitializer.selector);
        address(_eoa).call(initData);
    }

    function test_reverts_whenReadReverts() public {
        vm.expectRevert("MockRevert");
        MockImplementation(payable(_eoa)).revertingFunction();
    }

    function test_reverts_whenWriteReverts(address unauthorized) public {
        vm.assume(unauthorized != address(0));
        vm.assume(unauthorized != _newOwner); // Not the owner

        vm.prank(unauthorized);
        vm.expectRevert(MockImplementation.Unauthorized.selector);
        MockImplementation(payable(_eoa)).mockFunction();

        assertFalse(
            MockImplementation(payable(_eoa)).mockFunctionCalled(),
            "State should not change when write fails"
        );
    }

    function test_continues_delegating_afterUpgrade() public {
        // Setup will have already initialized the proxy with initial implementation and an owner

        // Deploy a new implementation
        MockImplementation newImplementation = new MockImplementation();

        // Upgrade to the new implementation
        vm.prank(_newOwner);
        MockImplementation(_eoa).upgradeToAndCall(
            address(newImplementation),
            ""
        );

        // Verify the implementation was changed
        assertEq(
            _getERC1967Implementation(_eoa),
            address(newImplementation),
            "Implementation should be updated"
        );

        // Try to make a call through the proxy
        vm.prank(_newOwner);
        MockImplementation(_eoa).mockFunction();

        // Verify the call succeeded
        assertTrue(
            MockImplementation(_eoa).mockFunctionCalled(),
            "Should be able to call through proxy after upgrade"
        );
    }

    // Add a specific test for ETH transfers
    function test_allows_ethTransfersBeforeInitialization() public {
        // Deploy a fresh proxy without initializing it
        address payable uninitProxy = payable(makeAddr("uninitProxy"));
        _deployProxy(uninitProxy);

        // Should succeed with empty calldata and ETH value
        (bool success, ) = uninitProxy.call{value: 1 ether}("");
        assertTrue(success, "ETH transfer should succeed");
        assertEq(address(uninitProxy).balance, 1 ether);
    }

    function test_reverts_whenCallingWithArbitraryDataBeforeInitialization(
        bytes calldata data
    ) public {
        // Skip empty calls or pure ETH transfers
        vm.assume(data.length > 0);

        // Deploy a fresh proxy without initializing it
        address payable uninitProxy = payable(makeAddr("uninitProxy"));
        _deployProxy(uninitProxy);

        vm.expectRevert(EIP7702Proxy.ProxyNotInitialized.selector);
        uninitProxy.call(data);
    }

    function test_reverts_whenCallingBeforeInitialization() public {
        // Deploy a fresh proxy without initializing it
        address payable uninitProxy = payable(makeAddr("uninitProxy"));
        _deployProxy(uninitProxy);

        vm.expectRevert(EIP7702Proxy.ProxyNotInitialized.selector);
        MockImplementation(payable(uninitProxy)).owner();
    }
}
