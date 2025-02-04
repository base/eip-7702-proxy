// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {EIP7702ProxyBase} from "../base/EIP7702ProxyBase.sol";
import {EIP7702Proxy} from "../../src/EIP7702Proxy.sol";
import {MockImplementation} from "../mocks/MockImplementation.sol";
import {IERC1967} from "openzeppelin-contracts/contracts/interfaces/IERC1967.sol";

/**
 * @title UpgradeToAndCallTest
 * @dev Tests ERC-1967 upgradeability functionality of EIP7702Proxy
 */
contract UpgradeToAndCallTest is EIP7702ProxyBase {
    MockImplementation newImplementation;

    function setUp() public override {
        super.setUp();

        // Initialize the proxy first
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signInitData(_EOA_PRIVATE_KEY, initArgs);
        EIP7702Proxy(_eoa).initialize(initArgs, signature);

        // Deploy new implementation
        newImplementation = new MockImplementation();
    }

    function test_succeeds_withValidOwnerAndImplementation() public {
        address oldImpl = _getERC1967Implementation(address(_eoa));

        vm.prank(_newOwner);

        // Expect the Upgraded event
        vm.expectEmit(true, false, false, false, address(_eoa));
        emit IERC1967.Upgraded(address(newImplementation));

        MockImplementation(payable(_eoa)).upgradeToAndCall(
            address(newImplementation),
            abi.encodeWithSelector(MockImplementation.mockFunction.selector)
        );

        // Verify implementation was upgraded
        address newImpl = _getERC1967Implementation(address(_eoa));
        assertNotEq(newImpl, oldImpl, "Implementation should have changed");
        assertEq(
            newImpl,
            address(newImplementation),
            "Implementation should be set to new address"
        );
    }

    function test_emitsUpgradedEvent_afterSuccess() public {
        vm.prank(_newOwner);

        vm.expectEmit(true, false, false, false, address(_eoa));
        emit IERC1967.Upgraded(address(newImplementation));

        MockImplementation(payable(_eoa)).upgradeToAndCall(
            address(newImplementation),
            ""
        );
    }

    function test_reverts_whenCalledByNonOwner(address nonOwner) public {
        vm.assume(nonOwner != address(0));
        vm.assume(nonOwner != _newOwner);
        assumeNotPrecompile(nonOwner);

        vm.prank(nonOwner);
        vm.expectRevert(MockImplementation.Unauthorized.selector); // From MockImplementation
        MockImplementation(payable(_eoa)).upgradeToAndCall(
            address(newImplementation),
            ""
        );

        // Verify implementation was not changed
        assertEq(
            _getERC1967Implementation(address(_eoa)),
            address(_implementation),
            "Implementation should not change on failed upgrade"
        );
    }
}
