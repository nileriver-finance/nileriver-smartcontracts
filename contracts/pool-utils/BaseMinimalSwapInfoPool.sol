// SPDX-License-Identifier: GPL-3.0-or-later


pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./BasePool.sol";
import "../interfaces/IMinimalSwapInfoPool.sol";

/**
 * @dev Extension of `BasePool`, adding a handler for `IMinimalSwapInfoPool.onSwap`.
 *
 * Derived contracts must call `BasePool`'s constructor, and implement `_onSwapGivenIn` and `_onSwapGivenOut` along with
 * `BasePool`'s virtual functions. Inheriting from this contract lets derived contracts choose the Two Token or Minimal
 * Swap Info specialization settings.
 */
abstract contract BaseMinimalSwapInfoPool is IMinimalSwapInfoPool, BasePool {
    // Swap Hooks

    function onSwap(
        SwapRequest memory request,
        uint256 balanceTokenIn,
        uint256 balanceTokenOut
    ) external view virtual override returns (uint256) {
        uint256 scalingFactorTokenIn = _scalingFactor(request.tokenIn);
        uint256 scalingFactorTokenOut = _scalingFactor(request.tokenOut);

        if (request.kind == IVault.SwapKind.GIVEN_IN) {
            // Fees are subtracted before scaling, to reduce the complexity of the rounding direction analysis.
            request.amount = _subtractSwapFeeAmount(request.amount);

            // All token amounts are upscaled.
            balanceTokenIn = _upscale(balanceTokenIn, scalingFactorTokenIn);
            balanceTokenOut = _upscale(balanceTokenOut, scalingFactorTokenOut);
            request.amount = _upscale(request.amount, scalingFactorTokenIn);

            uint256 amountOut = _onSwapGivenIn(request, balanceTokenIn, balanceTokenOut);

            // amountOut tokens are exiting the Pool, so we round down.
            return _downscaleDown(amountOut, scalingFactorTokenOut);
        } else {
            // All token amounts are upscaled.
            balanceTokenIn = _upscale(balanceTokenIn, scalingFactorTokenIn);
            balanceTokenOut = _upscale(balanceTokenOut, scalingFactorTokenOut);
            request.amount = _upscale(request.amount, scalingFactorTokenOut);

            uint256 amountIn = _onSwapGivenOut(request, balanceTokenIn, balanceTokenOut);

            // amountIn tokens are entering the Pool, so we round up.
            amountIn = _downscaleUp(amountIn, scalingFactorTokenIn);

            // Fees are added after scaling happens, to reduce the complexity of the rounding direction analysis.
            return _addSwapFeeAmount(amountIn);
        }
    }

    /*
     * @dev Called when a swap with the Pool occurs, where the amount of tokens entering the Pool is known.
     *
     * Returns the amount of tokens that will be taken from the Pool in return.
     *
     * All amounts inside `swapRequest`, `balanceTokenIn` and `balanceTokenOut` are upscaled. The swap fee has already
     * been deducted from `swapRequest.amount`.
     *
     * The return value is also considered upscaled, and will be downscaled (rounding down) before returning it to the
     * Vault.
     */
    function _onSwapGivenIn(
        SwapRequest memory swapRequest,
        uint256 balanceTokenIn,
        uint256 balanceTokenOut
    ) internal view virtual returns (uint256);

    /*
     * @dev Called when a swap with the Pool occurs, where the amount of tokens exiting the Pool is known.
     *
     * Returns the amount of tokens that will be granted to the Pool in return.
     *
     * All amounts inside `swapRequest`, `balanceTokenIn` and `balanceTokenOut` are upscaled.
     *
     * The return value is also considered upscaled, and will be downscaled (rounding up) before applying the swap fee
     * and returning it to the Vault.
     */
    function _onSwapGivenOut(
        SwapRequest memory swapRequest,
        uint256 balanceTokenIn,
        uint256 balanceTokenOut
    ) internal view virtual returns (uint256);
}
