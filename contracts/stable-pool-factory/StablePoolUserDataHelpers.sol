// SPDX-License-Identifier: GPL-3.0-or-later


pragma solidity ^0.7.0;

import "../../lib/openzeppelin/IERC20.sol";

import "./StablePool.sol";

library StablePoolUserDataHelpers {
    function joinKind(bytes memory self) internal pure returns (StablePool.JoinKind) {
        return abi.decode(self, (StablePool.JoinKind));
    }

    function exitKind(bytes memory self) internal pure returns (StablePool.ExitKind) {
        return abi.decode(self, (StablePool.ExitKind));
    }

    // Joins

    function initialAmountsIn(bytes memory self) internal pure returns (uint256[] memory amountsIn) {
        (, amountsIn) = abi.decode(self, (StablePool.JoinKind, uint256[]));
    }

    function exactTokensInForBptOut(bytes memory self)
        internal
        pure
        returns (uint256[] memory amountsIn, uint256 minBPTAmountOut)
    {
        (, amountsIn, minBPTAmountOut) = abi.decode(self, (StablePool.JoinKind, uint256[], uint256));
    }

    function tokenInForExactBptOut(bytes memory self) internal pure returns (uint256 bptAmountOut, uint256 tokenIndex) {
        (, bptAmountOut, tokenIndex) = abi.decode(self, (StablePool.JoinKind, uint256, uint256));
    }

    // Exits

    function exactBptInForTokenOut(bytes memory self) internal pure returns (uint256 bptAmountIn, uint256 tokenIndex) {
        (, bptAmountIn, tokenIndex) = abi.decode(self, (StablePool.ExitKind, uint256, uint256));
    }

    function exactBptInForTokensOut(bytes memory self) internal pure returns (uint256 bptAmountIn) {
        (, bptAmountIn) = abi.decode(self, (StablePool.ExitKind, uint256));
    }

    function bptInForExactTokensOut(bytes memory self)
        internal
        pure
        returns (uint256[] memory amountsOut, uint256 maxBPTAmountIn)
    {
        (, amountsOut, maxBPTAmountIn) = abi.decode(self, (StablePool.ExitKind, uint256[], uint256));
    }
}