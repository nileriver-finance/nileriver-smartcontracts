// SPDX-License-Identifier: GPL-3.0-or-later


pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../../lib/openzeppelin/Address.sol";
import "../../lib/helpers/BalancerErrors.sol";

import "./BasePool.sol";
import "./interfaces/IBasePoolRelayer.sol";
import "./interfaces/IRelayedBasePool.sol";

/**
 * @dev Base Pool associated with a relayer that guarantees it can only be joined/exited from the relayer itself.
 * This contract is a simple mixin for pools. Implementing pools must make sure to call the BasePool's constructor
 * properly.
 */
abstract contract RelayedBasePool is BasePool, IRelayedBasePool {
    using Address for address;

    IBasePoolRelayer internal immutable _relayer;

    modifier ensureRelayerCall(bytes32 poolId) {
        _require(_relayer.hasCalledPool(poolId), Errors.BASE_POOL_RELAYER_NOT_CALLED);
        _;
    }

    constructor(IBasePoolRelayer relayer) {
        _require(address(relayer).isContract(), Errors.RELAYER_NOT_CONTRACT);
        _relayer = relayer;
    }

    function getRelayer() public view override returns (IBasePoolRelayer) {
        return _relayer;
    }

    function onJoinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) public virtual override ensureRelayerCall(poolId) returns (uint256[] memory, uint256[] memory) {
        return
            super.onJoinPool(poolId, sender, recipient, balances, lastChangeBlock, protocolSwapFeePercentage, userData);
    }

    function onExitPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) public virtual override ensureRelayerCall(poolId) returns (uint256[] memory, uint256[] memory) {
        return
            super.onExitPool(poolId, sender, recipient, balances, lastChangeBlock, protocolSwapFeePercentage, userData);
    }
}
