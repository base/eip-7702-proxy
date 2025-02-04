// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {StorageSlot} from "openzeppelin-contracts/contracts/utils/StorageSlot.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

/**
 * @dev Custom upgradeability mechanism similar to UUPS but using a custom storage slot
 * that is computed during construction to avoid collisions in EIP-7702 context.
 *
 * The key difference from standard UUPS is the use of a deployment-specific
 * storage slot instead of the standard ERC-1967 slot, making it safe to use
 * in EIP-7702 where multiple delegates might share storage space.
 */
abstract contract CustomUpgradeable {
    /// @notice Emitted when the implementation is upgraded
    event Upgraded(address indexed implementation);

    /// @notice Emitted when a call is made from an unauthorized context (direct calls or invalid delegatecalls)
    error UnauthorizedCallContext();

    /// @dev For checking if the context is a delegate call
    address private immutable __self = address(this);

    /// @dev The storage slot used for the implementation
    bytes32 private immutable IMPLEMENTATION_SLOT;

    /**
     * @dev Initializes the implementation slot using implementation address and initializer
     * to ensure uniqueness across different deployments.
     *
     * The storage slot is computed by hashing:
     * - A namespace string ("eip7702.proxy.implementation")
     * - The initial implementation address
     * - The initializer function selector
     *
     * This ensures unique slots for different implementations of the proxy,
     * preventing storage collisions in EIP-7702 context.
     *
     * @param implementation The initial implementation address
     * @param initializer The function selector used for initialization
     */
    constructor(address implementation, bytes4 initializer) {
        IMPLEMENTATION_SLOT = keccak256(
            abi.encode(
                "eip7702.proxy.implementation",
                implementation,
                initializer
            )
        );
    }

    /**
     * @dev Upgrade the implementation and optionally execute a function.
     * Must be implemented by the proxy to define upgrade authorization rules.
     *
     * @param newImplementation Address of the new implementation
     * @param data Optional function call data to execute after upgrade
     * @param signature The signature authorizing the upgrade
     */
    function upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bytes calldata signature
    ) public payable virtual;

    /**
     * @dev Returns the current implementation address from the custom storage slot
     * computed during construction.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Updates the implementation address in the custom storage slot.
     * This function should only be called as part of an upgrade process.
     */
    function _setImplementation(address newImplementation) internal {
        StorageSlot
            .getAddressSlot(IMPLEMENTATION_SLOT)
            .value = newImplementation;
    }

    /**
     * @dev Ensures the call is through a proxy by checking:
     * 1. We are in a delegatecall context (address(this) != __self)
     * 2. The caller is the current implementation (_getImplementation() == __self)
     *
     * This prevents direct calls to the proxy and ensures upgrades are properly
     * authorized through the implementation contract.
     */
    modifier onlyProxy() {
        if (address(this) == __self || _getImplementation() != __self) {
            revert UnauthorizedCallContext();
        }
        _;
    }
}
