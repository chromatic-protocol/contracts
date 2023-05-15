// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IUSUMLiquidityCallback} from "@usum/core/interfaces/callback/IUSUMLiquidityCallback.sol";
import {LpToken} from "@usum/core/base/market/LpToken.sol";
import {MarketValue} from "@usum/core/base/market/MarketValue.sol";

abstract contract Liquidity is LpToken, MarketValue {
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
    ) external override nonReentrant returns (uint256 liquidity) {
        // liquidity = lpSlots.addLiquidity()
        // liquidity 수량만큼 token mint

        uint256 balanceBefore = settlementToken.balanceOf(address(vault));
        IUSUMLiquidityCallback(msg.sender).addLiquidityCallback(
            address(settlementToken),
            address(vault),
            data
        );
        uint256 amount = settlementToken.balanceOf(address(vault)) -
            balanceBefore;
        if (amount == 0) return 0;

        vault.onAddLiquidity(amount);

        uint256 id = encodeId(tradingFeeRate);

        liquidity = lpSlotSet.addLiquidity(
            newLpContext(),
            tradingFeeRate,
            amount,
            totalSupply(id)
        );

        _mint(recipient, id, liquidity, data);

        emit AddLiquidity(recipient, tradingFeeRate, id, amount, liquidity);
    }

    function removeLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external override nonReentrant returns (uint256 amount) {
        // amount = lpSlots.burn()
        // amount 만큼 settlement token transfer

        uint256 id = encodeId(tradingFeeRate);

        uint256 balanceBefore = balanceOf(address(this), id);

        IUSUMLiquidityCallback(msg.sender).removeLiquidityCallback(
            address(this),
            data
        );

        uint256 liquidity = balanceOf(address(this), id) - balanceBefore;
        if (liquidity == 0) return 0;

        uint256 _totalSupply = totalSupply(id);
        // int256 tradingFeeRate,
        // uint256 amount,
        // uint256 totalLiquidity

        amount = lpSlotSet.removeLiquidity(
            newLpContext(),
            tradingFeeRate,
            liquidity,
            _totalSupply
        );

        vault.onRemoveLiquidity(recipient, amount);

        _burn(address(this), id, liquidity);

        emit RemoveLiquidity(recipient, tradingFeeRate, id, amount, liquidity);
    }

    function getSlotMarginTotal(
        int16 tradingFeeRate
    ) external view override returns (uint256 amount) {
        return lpSlotSet.getSlotMarginTotal(tradingFeeRate);
    }

    function getSlotMarginUnused(
        int16 tradingFeeRate
    ) external view override returns (uint256 amount) {
        return lpSlotSet.getSlotMarginUnused(tradingFeeRate);
    }

    function distributeEarningToSlots(
        uint256 earning,
        uint256 marketBalance
    ) external onlyVault {
        lpSlotSet.distributeEarning(earning, marketBalance);
    }

    function calcLiquidity(
        int16 tradingFeeRate,
        uint256 amount
    ) external view returns (uint256 liquidity) {
        liquidity = lpSlotSet.calcLiquidity(
            newLpContext(),
            tradingFeeRate,
            amount,
            totalSupply(encodeId(tradingFeeRate))
        );
    }

    function calcAmount(
        int16 tradingFeeRate,
        uint256 liquidity
    ) external view returns (uint256 amount) {
        amount = lpSlotSet.calcAmount(
            newLpContext(),
            tradingFeeRate,
            liquidity,
            totalSupply(encodeId(tradingFeeRate))
        );
    }
}
