// SPDX-License-Identifier: GPL-3.0-or-later


pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../helpers/BaseSplitCodeFactory.sol";
import "../../contracts/interfaces/IVault.sol";

/**
 * @dev Same as `BasePoolFactory`, for Pools whose creation code is so large that the factory cannot hold it.
 */
abstract contract BasePoolSplitCodeFactory is BaseSplitCodeFactory {
    IVault private immutable _vault;
    mapping(address => bool) private _isPoolFromFactory;

    event PoolCreated(address indexed pool);

    constructor(IVault vault, bytes memory creationCode) BaseSplitCodeFactory(creationCode) {
        _vault = vault;
    }

    /**
     * @dev Returns the Vault's address.
     */
    function getVault() public view returns (IVault) {
        return _vault;
    }

    /**
     * @dev Returns true if `pool` was created by this factory.
     */
    function isPoolFromFactory(address pool) external view returns (bool) {
        return _isPoolFromFactory[pool];
    }

    function _create(bytes memory constructorArgs) internal override returns (address) {
        address pool = super._create(constructorArgs);

        _isPoolFromFactory[pool] = true;
        emit PoolCreated(pool);

        return pool;
    }
}
