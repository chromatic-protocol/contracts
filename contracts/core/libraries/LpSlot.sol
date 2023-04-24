// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {PositionParam} from "@usum/core/libraries/PositionParam.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlotPosition, LpSlotPositionLib} from "@usum/core/libraries/LpSlotPosition.sol";

struct LpSlot {
    uint256 total;
    LpSlotPosition _position;
}

using LpSlotLib for LpSlot global;

library LpSlotLib {
    using Math for uint256;
    using SignedMath for int256;
    using LpSlotPositionLib for LpSlotPosition;

    uint256 private constant MIN_AMOUNT = 1000; // almost zero, prevent divide by zero

    error TooSmallAmount();
    error NotEnoughSlotBalance();

    function openPosition(
        LpSlot storage self,
        LpContext memory ctx,
        PositionParam memory param,
        uint256 tradingFee
    ) internal {
        if (param.makerMargin > self.balance()) revert NotEnoughSlotBalance();

        self._position.openPosition(ctx, param);
        self.total += tradingFee;
    }

    function closePosition(
        LpSlot storage self,
        LpContext memory ctx,
        PositionParam memory param,
        int256 takerPnl
    ) internal {
        self._position.closePosition(ctx, param);

        uint256 absTakerPnl = takerPnl.abs();
        if (takerPnl < 0) {
            self.total += absTakerPnl;
        } else {
            self.total -= absTakerPnl;
        }
    }

    function balance(LpSlot storage self) internal view returns (uint256) {
        return self.total - self._position.totalMakerMargin();
    }

    function value(
        LpSlot storage self,
        LpContext memory ctx
    ) internal view returns (uint256) {
        int256 unrealizedPnl = self._position.unrealizedPnl(ctx);
        uint256 absPnl = unrealizedPnl.abs();

        return unrealizedPnl < 0 ? self.total - absPnl : self.total + absPnl;
    }

    function mint(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 amount,
        uint256 totalLiquidity
    ) internal returns (uint256 liquidity) {
        if (amount <= MIN_AMOUNT) revert TooSmallAmount();

        if (totalLiquidity == 0) {
            liquidity = amount;
        } else {
            uint256 slotValue = self.value(ctx);
            liquidity = amount.mulDiv(
                totalLiquidity,
                slotValue < MIN_AMOUNT ? MIN_AMOUNT : slotValue
            );
        }

        self.total += amount;
    }

    function burn(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 liquidity,
        uint256 totalLiquidity
    ) internal returns (uint256 amount) {
        amount = liquidity.mulDiv(self.value(ctx), totalLiquidity);
        if (amount > self.balance()) revert NotEnoughSlotBalance();

        self.total -= amount;
    }
}
