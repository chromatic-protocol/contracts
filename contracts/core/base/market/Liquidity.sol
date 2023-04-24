// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IUSUMLiquidityCallback} from "@usum/core/interfaces/callback/IUSUMLiquidityCallback.sol";
import {LpToken} from "@usum/core/base/market/LpToken.sol";
import {MarketValue} from "@usum/core/base/market/MarketValue.sol";
import {SafeERC20} from "@usum/core/libraries/SafeERC20.sol";
import {LpSlotKey, Direction} from "@usum/core/libraries/LpSlotKey.sol";

abstract contract Liquidity is LpToken, MarketValue {
    using Math for uint256;

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 public constant MINIMUM_MARKET_VALUATION = 10 ** 3;

    // uint256 internal lpReserveRatio;

    function mint(
        address recipient,
        LpSlotKey slotKey,
        bytes calldata data
    ) external override returns (uint256 liquidity) {
        // liquidity = lpSlots.mint()
        // liquidity 수량만큼 token mint

        uint256 balanceBefore = _balance();
        IUSUMLiquidityCallback(msg.sender).mintCallback(
            address(settlementToken),
            data
        );
        uint256 amount = _balance() - balanceBefore;
        if (amount == 0) return 0;

        liquidity = lpSlotSet.mint(
            newLpContext(),
            slotKey.signedTradingFeeRate(),
            amount,
            totalSupply(slotKey.unwrap())
        );

        _mint(recipient, slotKey.unwrap(), liquidity, data);
    }

    function burn(
        address recipient,
        LpSlotKey slotKey,
        bytes calldata data
    ) external override returns (uint256 amount) {
        // amount = lpSlots.burn()
        // amount 만큼 settlement token transfer

        uint256 balanceBefore = balanceOf(address(this), slotKey.unwrap());
        IUSUMLiquidityCallback(msg.sender).burnCallback(address(this), data);
        uint256 liquidity = balanceOf(address(this), slotKey.unwrap()) -
            balanceBefore;
        if (liquidity == 0) return 0;

        uint256 _totalSupply = totalSupply(slotKey.unwrap());
        // int256 tradingFeeRate,
        // uint256 amount,
        // uint256 totalLiquidity
        amount = lpSlotSet.burn(
            newLpContext(),
            slotKey.signedTradingFeeRate(),
            liquidity,
            _totalSupply
        );
        SafeERC20.safeTransfer(address(settlementToken), recipient, amount);
        _burn(recipient, slotKey.unwrap(), liquidity);
    }
}
