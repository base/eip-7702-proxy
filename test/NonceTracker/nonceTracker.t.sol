// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {NonceTracker} from "../../src/NonceTracker.sol";

contract NonceTrackerTest is Test {
    NonceTracker public nonceTracker;
    address public account;
    uint256 constant ACCOUNT_PK = 0xA11CE;

    event NonceUsed(address indexed account, uint256 nonce);

    function setUp() public {
        nonceTracker = new NonceTracker();
        account = vm.addr(ACCOUNT_PK);
    }

    function test_initialNonceIsZero() public {
        assertEq(
            nonceTracker.getNextNonce(account),
            0,
            "Initial nonce should be zero"
        );
    }

    function test_incrementsNonce_afterVerification() public {
        uint256 nonce = nonceTracker.getNextNonce(account);

        vm.prank(account);
        assertTrue(
            nonceTracker.verifyAndUseNonce(nonce),
            "Should verify and use nonce"
        );

        assertEq(
            nonceTracker.getNextNonce(account),
            nonce + 1,
            "Nonce should increment after use"
        );
    }

    function test_emitsEvent_whenNonceUsed() public {
        uint256 nonce = nonceTracker.getNextNonce(account);

        vm.expectEmit(true, false, false, true);
        emit NonceUsed(account, nonce);
        vm.prank(account);
        nonceTracker.verifyAndUseNonce(nonce);
    }

    function test_reverts_whenNonceInvalid(uint256 invalidNonce) public {
        uint256 expectedNonce = nonceTracker.getNextNonce(account);
        vm.assume(invalidNonce != expectedNonce);

        vm.prank(account);
        vm.expectRevert(NonceTracker.InvalidNonce.selector);
        nonceTracker.verifyAndUseNonce(invalidNonce);
    }

    function test_maintainsCorrectNonce_afterMultipleIncrements(
        uint8 incrementCount
    ) public {
        uint256 expectedNonce = 0;

        for (uint256 i = 0; i < incrementCount; i++) {
            assertEq(
                nonceTracker.getNextNonce(account),
                expectedNonce,
                "Incorrect nonce before increment"
            );

            vm.prank(account);
            assertTrue(
                nonceTracker.verifyAndUseNonce(expectedNonce),
                "Should verify and use nonce"
            );

            expectedNonce++;
        }

        assertEq(
            nonceTracker.getNextNonce(account),
            expectedNonce,
            "Final nonce incorrect"
        );
    }

    function test_tracksNoncesIndependently_forDifferentAccounts(
        address otherAccount
    ) public {
        vm.assume(otherAccount != account);

        // Use account's nonce
        uint256 accountNonce = nonceTracker.getNextNonce(account);
        vm.prank(account);
        assertTrue(nonceTracker.verifyAndUseNonce(accountNonce));

        // Other account's nonce should still be 0
        assertEq(
            nonceTracker.getNextNonce(otherAccount),
            0,
            "Other account's nonce should be independent"
        );
    }

    function test_reverts_whenReusingNonce() public {
        uint256 nonce = nonceTracker.getNextNonce(account);

        // Use nonce first time
        vm.prank(account);
        assertTrue(nonceTracker.verifyAndUseNonce(nonce));

        // Try to reuse same nonce
        vm.prank(account);
        vm.expectRevert(NonceTracker.InvalidNonce.selector);
        nonceTracker.verifyAndUseNonce(nonce);
    }

    function test_reverts_whenCallerNotAccount(address caller) public {
        vm.assume(caller != account);

        // Get nonces for both accounts
        uint256 accountNonce = nonceTracker.getNextNonce(account);
        uint256 callerNonce = nonceTracker.getNextNonce(caller);

        // Use caller's nonce to make sure it's different from account's
        vm.prank(caller);
        assertTrue(
            nonceTracker.verifyAndUseNonce(callerNonce),
            "Caller should be able to use their own nonce"
        );

        // Try to use account's nonce from a different address
        vm.prank(caller);
        vm.expectRevert(NonceTracker.InvalidNonce.selector);
        nonceTracker.verifyAndUseNonce(accountNonce);
    }
}
