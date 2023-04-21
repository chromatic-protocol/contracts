// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import {LpSlot} from "./LpSlotMock.sol";
import {PositionParam} from "./PositionParam.sol";
import {LpSlotMargin} from "./LpSlotMargin.sol";
using LpSlotSetLibMock for LpSlotSet global;

struct LpSlotSet {
    /// trading fee rate을 key로 하는 LpSlot의 map,
    /// taker의 long position에 대한 maker margin을 제공하는 slot으로
    /// slot의 position은 short position으로 관리됨
    mapping(uint256 => LpSlot) longSlots;
    // trading fee rate을 key로 하는 LpSlot의 map,
    // taker의 short position에 대한 maker margin을 제공하는 slot으로
    // slot의 position은 long position으로 관리됨
    mapping(uint256 => LpSlot) shortSlots;
    /// long position 체결시 유휴 margin이 있는 longSlots의 trading fee rate 최솟값
    uint256 minAvailableFeeRateLong;
    uint256 minAvailableFeeRateShort;
}

library LpSlotSetLibMock {
    function value(LpSlotSet storage self) internal {}

    function acceptOpenPosition(
        LpSlotSet storage self,
        PositionParam memory param
    ) internal returns (LpSlotMargin memory slotMargin) {}

    function acceptClosePosition(
        LpSlotSet storage self,
        PositionParam memory param
    ) internal {}

    function mint(
        LpSlotSet storage self,
        int256 tradingFeeRate,
        uint256 amount,
        uint256 totalLiquidity
    ) internal returns (uint256) {
        //
        // slots = tradingFeeRate > 0 ? self.longSlots : self.shortSlots
        // return slots[abs(tradingFeeRate)].mint(amount, totalLiquidity)
    }

    function burn(
        LpSlotSet storage self,
        int256 tradingFeeRate,
        uint256 amount,
        uint256 totalLiquidity
    ) internal returns (uint256) {}
}
