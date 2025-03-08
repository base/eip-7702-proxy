// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ACCOUNT_STATE_VALIDATION_SUCCESS} from "../../src/interfaces/IAccountStateValidator.sol";
import {Test} from "forge-std/Test.sol";

contract IAccountStateValidatorTest is Test {
    function testMagicValue() public {
        assertEq(ACCOUNT_STATE_VALIDATION_SUCCESS, bytes4(keccak256("validateAccountState(address,address)")));
    }
}
