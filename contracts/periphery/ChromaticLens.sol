// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarket} from "@chromatic/core/interfaces/IChromaticMarket.sol";
import {Position} from "@chromatic/core/libraries/Position.sol";
import {IOracleProvider} from "@chromatic/core/interfaces/IOracleProvider.sol";
import {Fixed18, UFixed18, Fixed18Lib} from "@equilibria/root/number/types/Fixed18.sol";
import {CLBTokenLib} from "@chromatic/core/libraries/CLBTokenLib.sol";
import {ICLBToken} from "@chromatic/core/interfaces/ICLBToken.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {BPS} from "@chromatic/core/libraries/Constants.sol";
import {LpReceipt} from "@chromatic/core/libraries/LpReceipt.sol";
import "hardhat/console.sol";

contract ChromaticLens {
    //
    using Math for uint256;

    struct EntryPriceStruct {
        uint256 positionId;
        Fixed18 price;
    }
    struct CLBValue {
        int16 tradingFeeRate;
        UFixed18 value; // 18 decimals
    }
    struct SlotValue {
        int16 tradingFeeRate;
        UFixed18 value; // 18 decimals
    }

    struct SlotLiquidity {
        int16 tradingFeeRate;
        uint256 liquidity;
        uint256 freeVolume;
    }

    function eachEntryPrice(
        IChromaticMarket market,
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

    function CLBValues(
        IChromaticMarket market,
        int16[] calldata tradingFeeRates
    ) external view returns (CLBValue[] memory results) {
        //
        SlotValue[] memory _slotValue = slotValue(market, tradingFeeRates);
        results = new CLBValue[](tradingFeeRates.length);
        for (uint256 i = 0; i < _slotValue.length; i++) {
            uint256 totalSupply = ICLBToken(market.clbToken()).totalSupply(
                CLBTokenLib.encodeId(tradingFeeRates[i])
            );

            results[i] = CLBValue(
                tradingFeeRates[i],
                totalSupply == 0
                    ? UFixed18.wrap(0)
                    : _slotValue[i].value.muldiv(10 ** 18, totalSupply)
            );
        }
    }

    function slotValue(
        IChromaticMarket market,
        int16[] calldata tradingFeeRates
    ) public view returns (SlotValue[] memory results) {
        uint256[] memory values = market.getSlotValues(tradingFeeRates);
        results = new SlotValue[](values.length);
        for (uint i = 0; i < values.length; i++) {
            results[i] = SlotValue(tradingFeeRates[i], UFixed18.wrap(values[i]));
        }
    }

    /**
     * get Liquidity information for each slot
     */
    function slotLiquidities(
        IChromaticMarket market,
        int16[] calldata tradingFeeRates //TODO use LpTokenId instead of tradingFeeRate
    ) external view returns (SlotLiquidity[] memory results) {
        // decode tradingFeeRate
        results = new SlotLiquidity[](tradingFeeRates.length);
        uint256[] memory liquidities = market.getSlotLiquidities(tradingFeeRates);
        uint256[] memory freeLiquidities = market.getSlotFreeLiquidities(tradingFeeRates);

        for (uint i = 0; i < tradingFeeRates.length; i++) {
            results[i] = SlotLiquidity(tradingFeeRates[i], liquidities[i], freeLiquidities[i]);
        }
    }

    function lpReceipts(
        IChromaticMarket market,
        uint256[] calldata receiptIds
    ) public view returns (LpReceipt[] memory result) {
        result = new LpReceipt[](receiptIds.length);
        for (uint i = 0; i < receiptIds.length; i++) {
            result[i] = market.getLpReceipt(receiptIds[i]);
        }
    }

    struct RemoveLiquidityInfo {
        uint256 receiptId;
        int16 tradingFeeRate;
        uint256 clbTokenAmount;
        uint256 burningAmount;
        uint256 tokenAmount;
    }

    // LpReceipt 에 대해서 settlement token 을 claim을 할 수 있는 진행정도를 구하기 위한 값..
    function removableLiquidity(
        IChromaticMarket market,
        uint256[] calldata receiptIds
    ) external view returns (RemoveLiquidityInfo[] memory results) {
        LpReceipt[] memory reciepts = lpReceipts(market, receiptIds);
        results = new RemoveLiquidityInfo[](receiptIds.length);
        for (uint i = 0; i < reciepts.length; i++) {
            (uint256 clbTokenAmount, uint256 burningAmount, uint256 tokenAmount) = market
                .getClaimBurning(reciepts[i]);
        
            results[i] = RemoveLiquidityInfo(
                reciepts[i].id,
                reciepts[i].tradingFeeRate,
                clbTokenAmount,
                burningAmount,
                tokenAmount
            );
        }
    }
}
