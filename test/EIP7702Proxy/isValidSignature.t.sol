// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {EIP7702ProxyBase} from "../base/EIP7702ProxyBase.sol";
import {EIP7702Proxy} from "../../src/EIP7702Proxy.sol";
import {MockImplementation, FailingSignatureImplementation, RevertingIsValidSignatureImplementation} from "../mocks/MockImplementation.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title IsValidSignatureTestBase
 * @dev Base contract for testing ERC-1271 isValidSignature behavior
 */
abstract contract IsValidSignatureTestBase is EIP7702ProxyBase {
    bytes4 constant ERC1271_MAGIC_VALUE = 0x1626ba7e;
    bytes4 constant ERC1271_FAIL_VALUE = 0xffffffff;

    bytes32 testHash;
    address wallet;

    function setUp() public virtual override {
        super.setUp();

        testHash = keccak256("test message");
        wallet = _eoa;
    }

    function test_succeeds_withValidEOASignature(
        bytes32 message
    ) public virtual {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_EOA_PRIVATE_KEY, message);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = MockImplementation(payable(wallet)).isValidSignature(
            message,
            signature
        );
        assertEq(
            result,
            ERC1271_MAGIC_VALUE,
            "Should accept valid EOA signature"
        );
    }

    function test_returnsExpectedValue_withInvalidEOASignature(
        uint128 wrongPk,
        bytes32 message
    ) public virtual {
        vm.assume(wrongPk != 0);
        vm.assume(wrongPk != _EOA_PRIVATE_KEY);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPk, testHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes4 result = MockImplementation(payable(wallet)).isValidSignature(
            message,
            signature
        );
        assertEq(
            result,
            expectedInvalidSignatureResult(),
            "Should handle invalid signature according to whether `isValidSignature` succeeds or fails"
        );
    }

    /**
     * @dev Abstract function that each implementation test must define
     * @return Expected result for invalid signature tests
     */
    function expectedInvalidSignatureResult()
        internal
        pure
        virtual
        returns (bytes4);
}

/**
 * @dev Tests isValidSignature behavior when returning failure value from implementation isValidSignature
 */
contract FailingImplementationTest is IsValidSignatureTestBase {
    function setUp() public override {
        super.setUp();

        // Override base setup to use FailingSignatureImplementation
        _implementation = new FailingSignatureImplementation();
        _initSelector = MockImplementation.initialize.selector;

        _eoa = payable(vm.addr(_EOA_PRIVATE_KEY));
        _newOwner = payable(vm.addr(_NEW_OWNER_PRIVATE_KEY));

        // Deploy and setup proxy
        _proxy = new EIP7702Proxy(
            address(_implementation),
            _initSelector,
            address(_nonceTracker)
        );
        bytes memory proxyCode = address(_proxy).code;
        vm.etch(_eoa, proxyCode);

        // Initialize
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signInitData(_EOA_PRIVATE_KEY, initArgs);
        EIP7702Proxy(_eoa).initialize(initArgs, signature);
    }

    function expectedInvalidSignatureResult()
        internal
        pure
        override
        returns (bytes4)
    {
        return ERC1271_FAIL_VALUE;
    }

    function test_returnsFailureValue_withEmptySignature(
        bytes32 message
    ) public {
        bytes4 result = MockImplementation(payable(wallet)).isValidSignature(
            message,
            ""
        );
        assertEq(result, ERC1271_FAIL_VALUE, "Should reject empty signature");
    }

    function test_reverts_whenCalledBeforeInitialization() public {
        // Deploy a fresh proxy without initializing
        address payable uninitProxy = payable(makeAddr("uninitProxy"));
        _deployProxy(uninitProxy);

        // Try to call isValidSignature
        bytes32 hash = keccak256("test message");
        bytes memory signature = new bytes(65);

        vm.expectRevert(EIP7702Proxy.ProxyNotInitialized.selector);
        EIP7702Proxy(uninitProxy).isValidSignature(hash, signature);
    }
}

/**
 * @dev Tests isValidSignature behavior when returning success value from implementation isValidSignature
 */
contract SucceedingImplementationTest is IsValidSignatureTestBase {
    function setUp() public override {
        super.setUp();

        // Override base implementation with standard MockImplementation (always succeeds)
        _implementation = new MockImplementation();
        _initSelector = MockImplementation.initialize.selector;

        _eoa = payable(vm.addr(_EOA_PRIVATE_KEY));
        _newOwner = payable(vm.addr(_NEW_OWNER_PRIVATE_KEY));

        // Deploy and setup proxy
        _proxy = new EIP7702Proxy(
            address(_implementation),
            _initSelector,
            address(_nonceTracker)
        );
        bytes memory proxyCode = address(_proxy).code;
        vm.etch(_eoa, proxyCode);

        // Initialize
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signInitData(_EOA_PRIVATE_KEY, initArgs);
        EIP7702Proxy(_eoa).initialize(initArgs, signature);
    }

    function expectedInvalidSignatureResult()
        internal
        pure
        override
        returns (bytes4)
    {
        return ERC1271_MAGIC_VALUE; // Implementation always returns success
    }

    function test_returnsSuccessValue_withEmptySignature(
        bytes32 message
    ) public {
        bytes4 result = MockImplementation(payable(wallet)).isValidSignature(
            message,
            ""
        );
        assertEq(
            result,
            ERC1271_MAGIC_VALUE,
            "Should return success for any EOA signature"
        );
    }
}

/**
 * @dev Tests isValidSignature behavior when reverting in implementation isValidSignature
 */
contract RevertingImplementationTest is IsValidSignatureTestBase {
    function setUp() public override {
        super.setUp();

        // Override base setup to use RevertingIsValidSignatureImplementation
        _implementation = new RevertingIsValidSignatureImplementation();
        _initSelector = MockImplementation.initialize.selector;

        _eoa = payable(vm.addr(_EOA_PRIVATE_KEY));
        _newOwner = payable(vm.addr(_NEW_OWNER_PRIVATE_KEY));

        // Deploy and setup proxy
        _proxy = new EIP7702Proxy(
            address(_implementation),
            _initSelector,
            address(_nonceTracker)
        );
        bytes memory proxyCode = address(_proxy).code;
        vm.etch(_eoa, proxyCode);

        // Initialize
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signInitData(_EOA_PRIVATE_KEY, initArgs);
        EIP7702Proxy(_eoa).initialize(initArgs, signature);
    }

    function expectedInvalidSignatureResult()
        internal
        pure
        override
        returns (bytes4)
    {
        return ERC1271_FAIL_VALUE;
    }
}
