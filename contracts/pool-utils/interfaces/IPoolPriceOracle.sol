// SPDX-License-Identifier: GPL-3.0-or-later


pragma solidity ^0.7.0;

interface IPoolPriceOracle {
    /**
     * @dev Returns the raw data of the sample at `index`.
     */
    function getSample(uint256 index)
        external
        view
        returns (
            int256 logPairPrice,
            int256 accLogPairPrice,
            int256 logBptPrice,
            int256 accLogBptPrice,
            int256 logInvariant,
            int256 accLogInvariant,
            uint256 timestamp
        );

    /**
     * @dev Returns the total number of samples.
     */
    function getTotalSamples() external view returns (uint256);
}
