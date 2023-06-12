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

contract ChromaticLens {
    //
    using Math for uint256;

    struct LiquidityBinValue {
        int16 tradingFeeRate;
        uint256 value;
    }

    struct LiquidityBinsParam {
        int16 tradingFeeRate;
        uint256 oracleVersion;
    }

    struct LiquidityBin {
        int16 tradingFeeRate;
        uint256 liquidity;
        uint256 freeVolume;
        uint256 clbTokenAmount;
        uint256 burningAmount;
        uint256 tokenAmount;
    }

    function oracleAtVersions(
        IChromaticMarket market,
        uint256[] calldata oracleVersions
    ) external view returns (IOracleProvider.OracleVersion[] memory results) {
        return market
            .oracleProvider()
            .atVersions(oracleVersions);
    }

    // get liquidity bin value with unrealized pnl
    function liquidityBinValue(
        IChromaticMarket market,
        int16[] calldata tradingFeeRates
    ) public view returns (LiquidityBinValue[] memory results) {
        results = new LiquidityBinValue[](tradingFeeRates.length);
        for (uint i = 0; i < tradingFeeRates.length; i++) {
            uint256 binValue = market.getBinValue(tradingFeeRates[i]);
            results[i] = LiquidityBinValue(tradingFeeRates[i], binValue);
        }
    }

    /**
     * get Liquidity information for each slot
     */
    function liquidityBins(
        IChromaticMarket market,
        LiquidityBinsParam[] memory params
    ) external view returns (LiquidityBin[] memory results) {
        results = new LiquidityBin[](params.length);
        for (uint i = 0; i < params.length; i++) {
            uint256 liquidity = market.getBinLiquidity(params[i].tradingFeeRate);
            uint256 freeLiquidity = market.getBinFreeLiquidity(params[i].tradingFeeRate);
            (uint256 clbTokenAmount, uint256 burningAmount, uint256 tokenAmount) = market
                .getClaimBurning(params[i].tradingFeeRate, params[i].oracleVersion);
            results[i] = LiquidityBin(
                params[i].tradingFeeRate,
                liquidity,
                freeLiquidity,
                clbTokenAmount,
                burningAmount,
                tokenAmount
            );
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

    function calculateCLBTokenValueBatch(
        address market,
        int16[] calldata tradingFeeRates,
        uint256[] calldata clbTokenAmounts
    ) external view returns (uint256[] memory results) {
        require(
            tradingFeeRates.length == clbTokenAmounts.length,
            "ChromaticLens: invalid arguments"
        );
        results = new uint256[](tradingFeeRates.length);
        for (uint i = 0; i < tradingFeeRates.length; i++) {
            results[i] = IChromaticMarket(market).calculateCLBTokenValue(
                tradingFeeRates[i],
                clbTokenAmounts[i]
            );
        }
    }

    function calculateCLBTokenMintingBatch(
        address market,
        int16[] calldata tradingFeeRates,
        uint256[] calldata amounts
    ) external view returns (uint256[] memory results) {
        require(tradingFeeRates.length == amounts.length, "ChromaticLens: invalid arguments");
        results = new uint256[](tradingFeeRates.length);
        for (uint i = 0; i < tradingFeeRates.length; i++) {
            results[i] = IChromaticMarket(market).calculateCLBTokenMinting(
                tradingFeeRates[i],
                amounts[i]
            );
        }
    }

    function totalSupplies(
        address market,
        int16[] calldata tradingFeeRates
    ) external view returns (uint256[] memory supplies) {
        supplies = new uint256[](tradingFeeRates.length);

        for (uint i = 0; i < tradingFeeRates.length; i++) {
            supplies[i] = ICLBToken(IChromaticMarket(market).clbToken()).totalSupply(
                CLBTokenLib.encodeId(tradingFeeRates[0])
            );
        }
    }
}
