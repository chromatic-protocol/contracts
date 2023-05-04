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

    // uint256 internal lpReserveRatio;

    function mint(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external override returns (uint256 liquidity) {
        // liquidity = lpSlots.mint()
        // liquidity 수량만큼 token mint

        uint256 balanceBefore = settlementToken.balanceOf(address(vault));
        IUSUMLiquidityCallback(msg.sender).mintCallback(
            address(settlementToken),
            address(vault),
            data
        );
        uint256 amount = settlementToken.balanceOf(address(vault)) -
            balanceBefore;
        if (amount == 0) return 0;

        vault.onMint(amount);

        uint256 id = encodeId(tradingFeeRate);

        liquidity = lpSlotSet.mint(
            newLpContext(),
            tradingFeeRate,
            amount,
            totalSupply(id)
        );

        _mint(recipient, id, liquidity, data);
    }

    function burn(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external override returns (uint256 amount) {
        // amount = lpSlots.burn()
        // amount 만큼 settlement token transfer

        uint256 id = encodeId(tradingFeeRate);

        uint256 balanceBefore = balanceOf(address(this), id);

        IUSUMLiquidityCallback(msg.sender).burnCallback(address(this), data);

        uint256 liquidity = balanceOf(address(this), id) - balanceBefore;
        if (liquidity == 0) return 0;

        uint256 _totalSupply = totalSupply(id);
        // int256 tradingFeeRate,
        // uint256 amount,
        // uint256 totalLiquidity

        amount = lpSlotSet.burn(
            newLpContext(),
            tradingFeeRate,
            liquidity,
            _totalSupply
        );

        vault.onBurn(recipient, amount);

        _burn(recipient, id, liquidity);
    }
}
