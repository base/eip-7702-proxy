// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {EIP7702Proxy} from "../../src/EIP7702Proxy.sol";
import {NonceTracker} from "../../src/NonceTracker.sol";

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
// import {ERC1967Utils} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {IERC1967} from "openzeppelin-contracts/contracts/interfaces/IERC1967.sol";

import {EIP7702ProxyBase} from "../base/EIP7702ProxyBase.sol";
import {MockImplementation} from "../mocks/MockImplementation.sol";
import {MockRevertingValidator} from "../mocks/MockRevertingValidator.sol";
import {IAccountStateValidator} from "../../src/interfaces/IAccountStateValidator.sol";
import {MockValidator} from "../mocks/MockValidator.sol";
import {MockInvalidValidator} from "../mocks/MockInvalidValidator.sol";
import {MockMaliciousImplementation} from "../mocks/MockMaliciousImplementation.sol";

contract SetImplementationTest is EIP7702ProxyBase {
    MockImplementation _newImplementation;

    function setUp() public override {
        super.setUp();
        _newImplementation = new MockImplementation();
    }

    function test_succeeds_whenImplementationSlotIsEmpty() public {
        assertEq(_getERC1967Implementation(_eoa), address(0), "Implementation should start empty");

        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signSetImplementationData(
            _EOA_PRIVATE_KEY,
            address(_implementation),
            0, // chainId 0 for cross-chain
            initArgs,
            address(_validator)
        );
        EIP7702Proxy(_eoa).setImplementation(
            address(_implementation),
            initArgs,
            address(_validator),
            signature,
            true // Allow cross-chain replay for tests
        );
        assertEq(
            _getERC1967Implementation(_eoa), address(_implementation), "Implementation should be set to new address"
        );
    }

    function test_succeeds_whenImplementationSlotAlreadySet() public {
        _initializeProxy(); // initialize the proxy with implementation
        assertEq(
            _getERC1967Implementation(_eoa),
            address(_implementation),
            "Implementation should be set to standard implementation"
        );
        MockValidator newImplementationValidator = new MockValidator(_newImplementation);

        bytes memory signature = _signSetImplementationData(
            _EOA_PRIVATE_KEY,
            address(_newImplementation),
            0, // chainId 0 for cross-chain
            "", // empty calldata
            address(newImplementationValidator)
        );

        EIP7702Proxy(_eoa).setImplementation(
            address(_newImplementation),
            "",
            address(newImplementationValidator), // same validator
            signature,
            true // allow cross-chain replay
        );

        assertEq(
            _getERC1967Implementation(_eoa), address(_newImplementation), "Implementation should be set to new address"
        );
    }

    function test_emitsUpgradedEvent() public {
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signSetImplementationData(
            _EOA_PRIVATE_KEY,
            address(_implementation),
            0, // chainId 0 for cross-chain
            initArgs,
            address(_validator)
        );

        vm.expectEmit(true, false, false, false, address(_eoa));
        emit IERC1967.Upgraded(address(_implementation));

        EIP7702Proxy(_eoa).setImplementation(
            address(_implementation),
            initArgs,
            address(_validator),
            signature,
            true // Allow cross-chain replay for tests
        );
    }

    function test_succeeds_withChainIdZero() public {
        assertEq(_getERC1967Implementation(_eoa), address(0), "Implementation should start empty");
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signSetImplementationData(
            _EOA_PRIVATE_KEY,
            address(_implementation),
            0, // chainId 0 for cross-chain
            initArgs,
            address(_validator)
        );
        EIP7702Proxy(_eoa).setImplementation(
            address(_implementation),
            initArgs,
            address(_validator),
            signature,
            true // Allow cross-chain replay
        );
        assertEq(
            _getERC1967Implementation(_eoa), address(_implementation), "Implementation should be set to new address"
        );
    }

    function test_succeeds_withNonzeroChainId() public {
        assertEq(_getERC1967Implementation(_eoa), address(0), "Implementation should start empty");
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signSetImplementationData(
            _EOA_PRIVATE_KEY,
            address(_implementation),
            block.chainid, // non-zero chainId
            initArgs,
            address(_validator)
        );

        EIP7702Proxy(_eoa).setImplementation(address(_implementation), initArgs, address(_validator), signature, false);
        assertEq(
            _getERC1967Implementation(_eoa), address(_implementation), "Implementation should be set to new address"
        );
    }

    function test_reverts_whenChainIdMismatch(uint256 wrongChainId) public {
        assertEq(_getERC1967Implementation(_eoa), address(0), "Implementation should start empty");

        vm.assume(wrongChainId != block.chainid);
        vm.assume(wrongChainId != 0);

        bytes memory initArgs = _createInitArgs(_newOwner);

        bytes32 initHash = keccak256(
            abi.encode(
                _IMPLEMENTATION_SET_TYPEHASH,
                wrongChainId,
                _proxy,
                _nonceTracker.nonces(_eoa),
                _getERC1967Implementation(_eoa),
                address(_implementation),
                keccak256(initArgs),
                address(_validator)
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_EOA_PRIVATE_KEY, initHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(EIP7702Proxy.InvalidSignature.selector);
        EIP7702Proxy(_eoa).setImplementation(address(_implementation), initArgs, address(_validator), signature, false);
    }

    function test_succeeds_whenSettingToSameImplementation() public {
        _initializeProxy(); // initialize the proxy with implementation
        assertEq(
            _getERC1967Implementation(_eoa),
            address(_implementation),
            "Implementation should be set to standard implementation"
        );
        bytes memory signature = _signSetImplementationData(
            _EOA_PRIVATE_KEY,
            address(_implementation), // same implementation
            0, // chainId 0 for cross-chain
            "", // empty calldata
            address(_validator)
        );

        EIP7702Proxy(_eoa).setImplementation(
            address(_implementation),
            "",
            address(_validator), // same validator
            signature,
            true // allow cross-chain replay
        );

        assertEq(
            _getERC1967Implementation(_eoa),
            address(_implementation),
            "Implementation should be set to same original address"
        );
    }

    function test_nonceIncrements_afterSuccessfulSetImplementation(uint8 numResets) public {
        vm.assume(numResets > 0 && numResets < 10);

        _initializeProxy(); // initialize the proxy with owner

        uint256 initialNonce = _nonceTracker.nonces(_eoa);

        for (uint8 i = 0; i < numResets; i++) {
            MockImplementation nextImplementation = new MockImplementation();
            MockValidator nextImplementationValidator = new MockValidator(nextImplementation);
            bytes memory signature = _signSetImplementationData(
                _EOA_PRIVATE_KEY, address(nextImplementation), block.chainid, "", address(nextImplementationValidator)
            );
            EIP7702Proxy(_eoa).setImplementation(
                address(nextImplementation), "", address(nextImplementationValidator), signature, false
            );

            assertEq(_nonceTracker.nonces(_eoa), initialNonce + i + 1, "Nonce should increment by one after each reset");
        }
    }

    function test_reverts_whenCalldataReverts() public {
        _initializeProxy(); // initialize the proxy with owner
        bytes memory reinitArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signSetImplementationData(
            _EOA_PRIVATE_KEY,
            address(_implementation),
            0, // chainId 0 for cross-chain
            reinitArgs, // attempt to reinitialize already-initialized implementation
            address(_validator)
        );

        vm.expectRevert();
        EIP7702Proxy(_eoa).setImplementation(
            address(_implementation),
            reinitArgs,
            address(_validator),
            signature,
            true // allow cross-chain replay
        );
    }

    function test_reverts_whenValidatorReverts() public {
        MockRevertingValidator revertingValidator = new MockRevertingValidator();

        bytes memory reinitArgs = _createInitArgs(_newOwner);
        bytes32 hash = keccak256(
            abi.encode(
                _IMPLEMENTATION_SET_TYPEHASH,
                0,
                _proxy,
                _nonceTracker.nonces(_eoa),
                _getERC1967Implementation(_eoa),
                address(_implementation),
                keccak256(reinitArgs),
                address(revertingValidator) // validator that always reverts
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_EOA_PRIVATE_KEY, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(EIP7702Proxy.InvalidValidation.selector);
        EIP7702Proxy(_eoa).setImplementation(
            address(_implementation), reinitArgs, address(revertingValidator), signature, true
        );
    }

    function test_reverts_whenSignatureEmpty() public {
        bytes memory signature = new bytes(0);

        vm.expectRevert(abi.encodeWithSignature("ECDSAInvalidSignatureLength(uint256)", 0));
        EIP7702Proxy(_eoa).setImplementation(address(_implementation), "", address(_validator), signature, false);
    }

    function test_reverts_whenSignatureLengthInvalid(uint8 length) public {
        vm.assume(length != 0);
        vm.assume(length != 65);

        bytes memory signature = new bytes(length);

        vm.expectRevert(abi.encodeWithSignature("ECDSAInvalidSignatureLength(uint256)", length));
        EIP7702Proxy(_eoa).setImplementation(address(_implementation), "", address(_validator), signature, false);
    }

    function test_reverts_whenSignatureInvalid(bytes32 r, bytes32 s, uint8 v) public {
        vm.assume(v != 27 && v != 28);

        bytes memory signature = abi.encodePacked(r, s, v);

        assertEq(signature.length, 65, "Signature should be 65 bytes");

        vm.expectRevert();
        EIP7702Proxy(_eoa).setImplementation(address(_implementation), "", address(_validator), signature, false);
    }

    function test_reverts_whenSignerWrong(uint128 wrongPk) public {
        vm.assume(wrongPk != 0);
        vm.assume(wrongPk != _EOA_PRIVATE_KEY);

        bytes32 messageHash = keccak256(
            abi.encode(
                _IMPLEMENTATION_SET_TYPEHASH,
                0,
                _proxy,
                _nonceTracker.nonces(_eoa),
                _getERC1967Implementation(_eoa),
                address(_implementation),
                keccak256(""),
                address(_validator)
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPk, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(EIP7702Proxy.InvalidSignature.selector);
        EIP7702Proxy(_eoa).setImplementation(address(_implementation), "", address(_validator), signature, true);
    }

    function test_reverts_whenSignatureReplayedWithDifferentProxy(uint128 secondProxyPk) public {
        // Deploy and initialize second proxy
        vm.assume(secondProxyPk != 0);
        vm.assume(secondProxyPk != uint128(_EOA_PRIVATE_KEY));

        address payable secondProxy = payable(vm.addr(secondProxyPk));
        vm.assume(address(secondProxy) != address(_eoa));
        assumeNotPrecompile(address(secondProxy));

        bytes memory proxyCode = address(_proxy).code;
        vm.etch(secondProxy, proxyCode);
        bytes memory initArgs = _createInitArgs(_newOwner);

        bytes32 messageHash = keccak256(
            abi.encode(
                _IMPLEMENTATION_SET_TYPEHASH,
                0,
                _proxy,
                _nonceTracker.nonces(secondProxy),
                _getERC1967Implementation(secondProxy),
                address(_implementation),
                keccak256(initArgs),
                address(_validator)
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(secondProxyPk, messageHash);
        bytes memory initSecondProxySignature = abi.encodePacked(r, s, v);
        EIP7702Proxy(secondProxy).setImplementation(
            address(_implementation), initArgs, address(_validator), initSecondProxySignature, true
        );

        // create signature for original proxy
        bytes memory signature = _signSetImplementationData(
            _EOA_PRIVATE_KEY, address(_newImplementation), block.chainid, "", address(_validator)
        );

        // attempt to play signature on second proxy
        vm.expectRevert(EIP7702Proxy.InvalidSignature.selector);
        EIP7702Proxy(secondProxy).setImplementation(
            address(_newImplementation), "", address(_validator), signature, false
        );
    }

    function test_reverts_whenSignatureReplayedWithDifferentImplementation(address differentImpl) public {
        vm.assume(differentImpl != address(0));
        vm.assume(differentImpl != address(_implementation));
        assumeNotPrecompile(differentImpl);

        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signSetImplementationData(
            _EOA_PRIVATE_KEY,
            address(_implementation), // sign over standard implementation
            block.chainid,
            initArgs,
            address(_validator)
        );

        vm.expectRevert(EIP7702Proxy.InvalidSignature.selector);
        EIP7702Proxy(_eoa).setImplementation(
            differentImpl, // different implementation than signed over
            initArgs,
            address(_validator),
            signature,
            false
        );
    }

    function test_reverts_whenSignatureReplayedWithDifferentArgs(bytes memory differentInitArgs) public {
        bytes memory initArgs = _createInitArgs(_newOwner);
        vm.assume(keccak256(differentInitArgs) != keccak256(initArgs));
        bytes memory signature = _signSetImplementationData(
            _EOA_PRIVATE_KEY, address(_implementation), block.chainid, initArgs, address(_validator)
        );

        vm.expectRevert(EIP7702Proxy.InvalidSignature.selector);
        EIP7702Proxy(_eoa).setImplementation(
            address(_implementation), differentInitArgs, address(_validator), signature, false
        );
    }

    function test_reverts_whenSignatureReplayedWithDifferentValidator(address differentValidator) public {
        vm.assume(differentValidator != address(_validator));
        vm.assume(differentValidator != address(0));

        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signSetImplementationData(
            _EOA_PRIVATE_KEY, address(_implementation), block.chainid, initArgs, address(_validator)
        );

        vm.expectRevert(EIP7702Proxy.InvalidSignature.selector);
        EIP7702Proxy(_eoa).setImplementation(address(_implementation), initArgs, differentValidator, signature, false);
    }

    function test_reverts_whenSignatureUsesWrongNonce(uint256 wrongNonce) public {
        uint256 currentNonce = _nonceTracker.nonces(_eoa);

        vm.assume(wrongNonce != currentNonce);

        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes32 initHash = keccak256(
            abi.encode(
                _IMPLEMENTATION_SET_TYPEHASH,
                block.chainid,
                _proxy,
                wrongNonce, // wrong nonce
                _getERC1967Implementation(_eoa),
                address(_implementation),
                keccak256(initArgs),
                address(_validator)
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_EOA_PRIVATE_KEY, initHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(EIP7702Proxy.InvalidSignature.selector);
        EIP7702Proxy(_eoa).setImplementation(address(_implementation), initArgs, address(_validator), signature, false);
    }

    function test_reverts_whenSignatureReplayedWithSameNonce() public {
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signSetImplementationData(
            _EOA_PRIVATE_KEY, address(_implementation), block.chainid, initArgs, address(_validator)
        );
        EIP7702Proxy(_eoa).setImplementation(address(_implementation), initArgs, address(_validator), signature, false);
        assertEq(
            _getERC1967Implementation(_eoa),
            address(_implementation),
            "Implementation should be set to standard implementation"
        );

        // attempt to replay signature with same nonce
        vm.expectRevert(EIP7702Proxy.InvalidSignature.selector);
        EIP7702Proxy(_eoa).setImplementation(address(_implementation), initArgs, address(_validator), signature, false);
    }

    function test_reverts_whenSignatureUsesWrongCurrentImplementation() public {
        assertEq(_getERC1967Implementation(_eoa), address(0), "Implementation should start empty");

        MockImplementation wrongCurrentImpl = new MockImplementation();

        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes32 initHash = keccak256(
            abi.encode(
                _IMPLEMENTATION_SET_TYPEHASH,
                block.chainid,
                _proxy,
                _nonceTracker.nonces(_eoa),
                address(wrongCurrentImpl), // wrong current implementation
                address(_implementation),
                keccak256(initArgs),
                address(_validator)
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_EOA_PRIVATE_KEY, initHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(EIP7702Proxy.InvalidSignature.selector);
        EIP7702Proxy(_eoa).setImplementation(address(_implementation), initArgs, address(_validator), signature, false);
    }

    function test_reverts_whenImplementationDoesNotMatchValidator() public {
        MockImplementation expectedImpl = new MockImplementation();
        MockImplementation actualImpl = new MockImplementation();

        // Create mock validator expecting a specific implementation
        MockValidator validator = new MockValidator(expectedImpl);

        bytes memory signature =
            _signSetImplementationData(_EOA_PRIVATE_KEY, address(actualImpl), 0, "", address(validator));

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccountStateValidator.InvalidImplementation.selector, address(expectedImpl), address(actualImpl)
            )
        );
        EIP7702Proxy(_eoa).setImplementation(address(actualImpl), "", address(validator), signature, true);
    }

    function test_succeeds_whenImplementationMatchesValidator() public {
        // Create mock validator with matching implementation
        MockValidator validator = new MockValidator(_implementation);

        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature =
            _signSetImplementationData(_EOA_PRIVATE_KEY, address(_implementation), 0, initArgs, address(validator));

        // Should not revert
        EIP7702Proxy(_eoa).setImplementation(address(_implementation), initArgs, address(validator), signature, true);

        assertEq(
            _getERC1967Implementation(_eoa),
            address(_implementation),
            "Implementation should be set to expected address"
        );
    }

    function test_reverts_whenValidatorReturnsWrongMagicValue() public {
        MockInvalidValidator invalidValidator = new MockInvalidValidator();

        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signSetImplementationData(
            _EOA_PRIVATE_KEY, address(_implementation), 0, initArgs, address(invalidValidator)
        );

        vm.expectRevert(EIP7702Proxy.InvalidValidation.selector);
        EIP7702Proxy(_eoa).setImplementation(
            address(_implementation), initArgs, address(invalidValidator), signature, true
        );
    }

    function test_reverts_whenValidatorIsEOA() public {
        address eoaValidator = makeAddr("eoaValidator");

        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature =
            _signSetImplementationData(_EOA_PRIVATE_KEY, address(_implementation), 0, initArgs, eoaValidator);

        vm.expectRevert();
        EIP7702Proxy(_eoa).setImplementation(address(_implementation), initArgs, eoaValidator, signature, true);
    }

    function test_reverts_whenValidatorIsNonCompliantContract() public {
        // Deploy a contract that doesn't implement IAccountStateValidator
        MockImplementation nonCompliantValidator = new MockImplementation();

        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature = _signSetImplementationData(
            _EOA_PRIVATE_KEY, address(_implementation), 0, initArgs, address(nonCompliantValidator)
        );

        vm.expectRevert();
        EIP7702Proxy(_eoa).setImplementation(
            address(_implementation), initArgs, address(nonCompliantValidator), signature, true
        );
    }

    function test_reverts_whenImplementationChangesItsOwnImplementation() public {
        // Create a chain of implementations
        MockImplementation finalImpl = new MockImplementation();
        MockMaliciousImplementation maliciousImpl = new MockMaliciousImplementation(address(finalImpl));

        // Create validator expecting the malicious implementation
        MockValidator validator = new MockValidator(maliciousImpl);

        // Try to initialize with the malicious implementation
        bytes memory initArgs = _createInitArgs(_newOwner);
        bytes memory signature =
            _signSetImplementationData(_EOA_PRIVATE_KEY, address(maliciousImpl), 0, initArgs, address(validator));

        // Should revert because after initialization, the implementation
        // will be finalImpl but validator expects maliciousImpl
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccountStateValidator.InvalidImplementation.selector, address(maliciousImpl), address(finalImpl)
            )
        );
        EIP7702Proxy(_eoa).setImplementation(address(maliciousImpl), initArgs, address(validator), signature, true);
    }
}
