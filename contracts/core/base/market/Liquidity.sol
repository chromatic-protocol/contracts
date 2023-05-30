// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {IUSUMLiquidityCallback} from '@usum/core/interfaces/callback/IUSUMLiquidityCallback.sol';
import {LpContext} from '@usum/core/libraries/LpContext.sol';
import {LpTokenLib} from '@usum/core/libraries/LpTokenLib.sol';
import {MarketValue} from '@usum/core/base/market/MarketValue.sol';

abstract contract Liquidity is MarketValue {
    using Math for uint256;

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 public constant MINIMUM_MARKET_VALUATION = 10 ** 3;

    error OnlyAccessableByVault();

    modifier onlyVault() {
        if (msg.sender != address(vault)) revert OnlyAccessableByVault();
        _;
    }

    function addLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external override nonReentrant returns (uint256 lpTokenAmount) {
        uint256 balanceBefore = settlementToken.balanceOf(address(vault));
        IUSUMLiquidityCallback(msg.sender).addLiquidityCallback(address(settlementToken), address(vault), data);
        uint256 amount = settlementToken.balanceOf(address(vault)) - balanceBefore;
        if (amount == 0) return 0;

        vault.onAddLiquidity(amount);

        uint256 id = LpTokenLib.encodeId(tradingFeeRate);

        LpContext memory ctx = newLpContext();
        ctx.syncOracleVersion();

        lpTokenAmount = lpSlotSet.addLiquidity(ctx, tradingFeeRate, amount, lpToken.totalSupply(id));

        lpToken.mint(recipient, id, lpTokenAmount, data);

        emit AddLiquidity(recipient, tradingFeeRate, id, amount, lpTokenAmount);
    }

    function removeLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external override nonReentrant returns (uint256 amount) {
        uint256 id = LpTokenLib.encodeId(tradingFeeRate);
        uint256 balanceBefore = lpToken.balanceOf(address(lpToken), id);

        IUSUMLiquidityCallback(msg.sender).removeLiquidityCallback(address(lpToken), data);

        uint256 lpTokenAmount = lpToken.balanceOf(address(lpToken), id) - balanceBefore;
        if (lpTokenAmount == 0) return 0;

        uint256 _totalSupply = lpToken.totalSupply(id);

        LpContext memory ctx = newLpContext();
        ctx.syncOracleVersion();

        amount = lpSlotSet.removeLiquidity(ctx, tradingFeeRate, lpTokenAmount, _totalSupply);

        vault.onRemoveLiquidity(recipient, amount);

        lpToken.burn(address(lpToken), id, lpTokenAmount);

        emit RemoveLiquidity(recipient, tradingFeeRate, id, amount, lpTokenAmount);
    }

    function getSlotLiquidities(
        int16[] memory tradingFeeRates
    ) external view override returns (uint256[] memory amounts) {
        amounts = new uint256[](tradingFeeRates.length);
        for (uint i = 0; i < tradingFeeRates.length; i++) {
            amounts[i] = lpSlotSet.getSlotLiquidity(tradingFeeRates[i]);
        }
    }

    function getSlotFreeLiquidities(
        int16[] memory tradingFeeRates
    ) external view override returns (uint256[] memory amounts) {
        amounts = new uint256[](tradingFeeRates.length);
        for (uint i = 0; i < tradingFeeRates.length; i++) {
            amounts[i] = lpSlotSet.getSlotFreeLiquidity(tradingFeeRates[i]);
        }
    }

    function distributeEarningToSlots(uint256 earning, uint256 marketBalance) external onlyVault {
        lpSlotSet.distributeEarning(earning, marketBalance);
    }

    function calculateLiquidity(int16 tradingFeeRate, uint256 amount) external view returns (uint256 lpTokenAmount) {
        lpTokenAmount = lpSlotSet.calculateLiquidity(
            newLpContext(),
            tradingFeeRate,
            amount,
            lpToken.totalSupply(LpTokenLib.encodeId(tradingFeeRate))
        );
    }

    function calculateAmount(int16 tradingFeeRate, uint256 lpTokenAmount) external view returns (uint256 amount) {
        amount = lpSlotSet.calculateAmount(
            newLpContext(),
            tradingFeeRate,
            lpTokenAmount,
            lpToken.totalSupply(LpTokenLib.encodeId(tradingFeeRate))
        );
    }
}
