// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LpSlotPosition} from "@usum/core/libraries/LpSlotPosition.sol";
import {PositionParam} from "./PositionParam.sol";

using LpSlotLib for LpSlot global;

struct LpSlot {
    /// uint256, slot에 예치된 전체 금액
    /// LP의 예치금 뿐만 아니라, closePosition()시 발생한 slot의 이익 및 interest 도 포함된 금액
    uint256 total;
    /// uint256 maker margin으로 사용중인 금액, total - collateral 이상은 인출 불가
    uint256 collateral;
    LpSlotPosition position;
}

library LpSlotLib {
    function value(LpSlot memory self) internal returns (uint256) {
        // slot의 현재가치 계산
        // unrealized pnl, unsettled interest를 모두 포함한 가치
    }

    function openPosition(
        LpSlot storage self,
        PositionParam memory param,
        uint256 request
    ) internal returns (uint256) {
        // slotMargin: uint256, request amount 값에서 maker margin으로 reserve 가능한 amount
        // self.position.openPosition(param, slotMargin)
        // self.collateral += slotMargin
        // return slotMargin
    }

    function closePosition(
        LpSlot storage self,
        PositionParam memory param,
        uint256 slotMargin,
        int256 takerPnl
    ) internal {
        // self.position.closePosition(param, slotMargin)
        // self.collateral -= slotMargin
        // self.total -= takerPnl
    }

    function mint(
        LpSlot storage self,
        uint256 amount,
        uint256 totalLiquidity
    ) internal returns (uint256) {
        // liquidity = amount * totalLiquidity / value()
        // self.total += amount
        // return liquidity
    }

    function burn(
        LpSlot storage self,
        uint256 liquidity,
        uint256 totalLiquidity
    ) internal returns (uint256) {
        // amount = liquidity * value() / totalLiquidity
        // require(amount >= self.total - self.collateral)
        // self.total -= amount
        // return amount
    }
}
