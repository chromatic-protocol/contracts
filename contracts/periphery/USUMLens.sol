// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";
import {Position} from "@usum/core/libraries/Position.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {Fixed18} from "@equilibria/root/number/types/Fixed18.sol";
import {LpTokenLib} from "@usum/core/libraries/LpTokenLib.sol";
import {IUSUMLpToken} from "@usum/core/interfaces/IUSUMLpToken.sol";

contract USUMLens {
    //

    struct EntryPriceStruct {
        uint256 positionId;
        Fixed18 price;
    }
    struct CLBValue {
        int16 tradingFeeRate;
        uint256 value;
    }
    struct SlotValue {
        int16 tradingFeeRate;
        uint256 value;
    }

    struct SlotLiquidity {
        int16 tradingFeeRate;
        uint256 liquidity;
        uint256 freeVolume;
    }

    function eachEntryPrice(
        IUSUMMarket market,
        uint256[] calldata positionIds
    ) external view returns (EntryPriceStruct[] memory results) {
        results = new EntryPriceStruct[](positionIds.length);
        Position[] memory positions = market.getPositions(positionIds);
        uint256[] memory openVersions = new uint256[](positions.length);
        for (uint i = 0; i < positions.length; i++) {
            openVersions[i] = positions[i].openVersion;
        }
        IOracleProvider.OracleVersion[] memory oracleVersions = market.oracleProvider().atVersions(
            openVersions
        );
        for (uint i = 0; i < oracleVersions.length; i++) {
            results[i] = EntryPriceStruct(positionIds[i], oracleVersions[i].price);
        }
    }

    // lpTokenValue(slotIds? ) : { slotId, value:number }
    function CLBValues(
        IUSUMMarket market,
        int16[] calldata tradingFeeRates
    ) external view returns (CLBValue[] memory results) {
        //
        SlotValue[] memory _slotValue = slotValue(market, tradingFeeRates);
        results = new CLBValue[](tradingFeeRates.length);
        for (uint256 i = 0; i < _slotValue.length; i++) {
            uint256 totalSupply = IUSUMLpToken(market.lpToken()).totalSupply(
                LpTokenLib.encodeId(tradingFeeRates[i])
            );
            results[i] = CLBValue(
                tradingFeeRates[i],
                totalSupply == 0 ? 0 : _slotValue[i].value / totalSupply
            );
        }
    }

    // lpSlotVolume(slotIds?) : { slotId, volume:number }

    function slotValue(
        IUSUMMarket market,
        int16[] calldata tradingFeeRates
    ) public view returns (SlotValue[] memory results) {
        uint256[] memory values = market.getSlotValues(tradingFeeRates);
        results = new SlotValue[](values.length);
        for (uint i = 0; i < values.length; i++) {
            results[i] = SlotValue(tradingFeeRates[i], values[i]);
        }
    }

    /**
     * get Liquidity information for each slot
     */
    function slotLiquidities(
        IUSUMMarket market,
        int16[] calldata tradingFeeRates
    ) external view returns (SlotLiquidity[] memory results) {
        results = new SlotLiquidity[](tradingFeeRates.length);
        uint256[] memory liquidities = market.getSlotLiquidities(tradingFeeRates);
        uint256[] memory freeLiquidities = market.getSlotFreeLiquidities(tradingFeeRates);

        for (uint i = 0; i < tradingFeeRates.length; i++) {
            results[i] = SlotLiquidity(tradingFeeRates[i], liquidities[i], freeLiquidities[i]);
        }
    }

    //TODO [Trade] removeLiquidity 의 진행률?
}
