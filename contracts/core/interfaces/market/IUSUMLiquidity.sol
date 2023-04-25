// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

interface IUSUMLiquidity {
    function mint(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external returns (uint256 liquidity);

    function burn(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external returns (uint256 amount);
}
