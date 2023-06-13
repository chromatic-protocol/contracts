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

/**
 * @title ChromaticLens
 * @dev A contract that provides utility functions for interacting with Chromatic markets.
 */
contract ChromaticLens {
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
        uint256 freeLiquidity;
        uint256 clbTokenAmount;
        uint256 burningAmount;
        uint256 tokenAmount;
    }

    /**
     * @dev Retrieves the Oracle versions for the specified oracle versions in the given Chromatic market.
     * @param market The address of the Chromatic market contract.
     * @param oracleVersions An array of Oracle versions.
     * @return results An array of OracleVersion containing the Oracle versions for each oracle version.
     */
    function oracleAtVersions(
        IChromaticMarket market,
        uint256[] calldata oracleVersions
    ) external view returns (IOracleProvider.OracleVersion[] memory results) {
        return market.oracleProvider().atVersions(oracleVersions);
    }

    /**
     * @dev Retrieves the liquidity bin values for the specified trading fee rates in the given Chromatic market.
     * @param market The address of the Chromatic market contract.
     * @param tradingFeeRates An array of trading fee rates.
     * @return results An array of LiquidityBinValue containing the liquidity bin values for each trading fee rate.
     */
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
     * @dev Retrieves the liquidity information for each liquidity bin specified by the trading fee rates and Oracle versions in the given Chromatic market.
     * @param market The address of the Chromatic market contract.
     * @param params An array of LiquidityBinsParam containing the trading fee rates and Oracle versions.
     * @return results An array of LiquidityBin containing the liquidity information for each trading fee rate and Oracle version.
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

    /**
     * @dev Retrieves the LP receipts for the specified receipt IDs in the given Chromatic market.
     * @param market The address of the Chromatic market contract.
     * @param receiptIds An array of receipt IDs.
     * @return result An array of LpReceipt containing the LP receipts for each receipt ID.
     */
    function lpReceipts(
        IChromaticMarket market,
        uint256[] calldata receiptIds
    ) public view returns (LpReceipt[] memory result) {
        result = new LpReceipt[](receiptIds.length);
        for (uint i = 0; i < receiptIds.length; i++) {
            result[i] = market.getLpReceipt(receiptIds[i]);
        }
    }

    /**
     * @dev Calculates the value of CLB tokens for each trading fee rate and CLB token amount in the given Chromatic market.
     * @param market The address of the Chromatic market contract.
     * @param tradingFeeRates An array of trading fee rates.
     * @param clbTokenAmounts An array of CLB token amounts.
     * @return results An array of uint256 containing the calculated CLB token values for each trading fee rate and CLB token amount.
     */
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

    /**
     * @dev Calculates the amount of CLB tokens to be minted for each trading fee rate and specified amount in the given Chromatic market.
     * @param market The address of the Chromatic market contract.
     * @param tradingFeeRates An array of trading fee rates.
     * @param amounts An array of specified amounts.
     * @return results An array of uint256 containing the calculated CLB token minting amounts for each trading fee rate and specified amount.
     */
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

    /**
     * @dev Retrieves the total supply of CLB tokens for each trading fee rate in the given Chromatic market.
     * @param market The address of the Chromatic market contract.
     * @param tradingFeeRates An array of trading fee rates.
     * @return supplies An array of uint256 containing the total supply of CLB tokens for each trading fee rate.
     */
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
