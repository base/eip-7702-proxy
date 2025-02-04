// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

/**
 * @title MockImplementation
 * @dev Base mock implementation for testing EIP7702Proxy
 */
contract MockImplementation is UUPSUpgradeable {
    bytes4 constant ERC1271_MAGIC_VALUE = 0x1626ba7e;

    address public owner;
    bool public initialized;
    bool public mockFunctionCalled;

    event Initialized(address owner);
    event MockFunctionCalled();

    error Unauthorized();
    error AlreadyInitialized();

    /// @dev Modifier to restrict access to owner
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    /// @dev Modifier to prevent multiple initializations
    modifier initializer() {
        if (initialized) revert AlreadyInitialized();
        initialized = true;
        _;
    }

    /**
     * @dev Initializes the contract with an owner
     * @param _owner Address to set as owner
     */
    function initialize(address _owner) public virtual initializer {
        owner = _owner;
        emit Initialized(_owner);
    }

    /**
     * @dev Mock function for testing delegate calls
     */
    function mockFunction() public onlyOwner {
        mockFunctionCalled = true;
        emit MockFunctionCalled();
    }

    function isValidSignature(
        bytes32,
        bytes calldata
    ) external pure virtual returns (bytes4) {
        return ERC1271_MAGIC_VALUE;
    }

    /**
     * @dev Implementation of UUPS upgrade authorization
     */
    function _authorizeUpgrade(
        address
    ) internal view virtual override onlyOwner {}

    /**
     * @dev Mock function that returns arbitrary bytes data
     * @param data The data to return
     * @return The input data (to verify delegation preserves data)
     */
    function returnBytesData(
        bytes memory data
    ) public pure returns (bytes memory) {
        return data;
    }

    /**
     * @dev Mock function that always reverts
     */
    function revertingFunction() public pure {
        revert("MockRevert");
    }
}

/**
 * @title FailingSignatureImplementation
 * @dev Mock implementation that always fails signature validation
 */
contract FailingSignatureImplementation is MockImplementation {
    /// @dev Always returns failure for signature validation
    function isValidSignature(
        bytes32,
        bytes calldata
    ) external pure override returns (bytes4) {
        return 0xffffffff;
    }
}

/**
 * @title RevertingIsValidSignatureImplementation
 * @dev Mock implementation that always reverts during signature validation
 */
contract RevertingIsValidSignatureImplementation is MockImplementation {
    /// @dev Always reverts during signature validation
    function isValidSignature(
        bytes32,
        bytes calldata
    ) external pure override returns (bytes4) {
        revert("SignatureValidationFailed");
    }
}

/**
 * @title RevertingInitializerMockImplementation
 * @dev Mock implementation that always reverts on initialization
 */
contract RevertingInitializerMockImplementation is MockImplementation {
    /// @dev Always reverts on initialization
    function initialize(address) public pure override {
        revert("InitializerReverted");
    }
}
