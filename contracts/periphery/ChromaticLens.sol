// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {BPS, FEE_RATES_LENGTH} from "@chromatic-protocol/contracts/core/libraries/Constants.sol";
import {IChromaticRouter} from "@chromatic-protocol/contracts/periphery/interfaces/IChromaticRouter.sol";

/**
 * @title ChromaticLens
 * @dev A contract that provides utility functions for interacting with Chromatic markets.
 */
contract ChromaticLens {
    using Math for uint256;

    struct CLBBalance {
        uint256 tokenId;
        uint256 balance;
        uint256 totalSupply;
        uint256 binValue;
    }

    IChromaticRouter immutable router;

    constructor(IChromaticRouter _router) {
        router = _router;
    }

    /**
     * @dev Retrieves the OracleVersion for the specified oracle version in the given Chromatic market.
     * @param market The address of the Chromatic market contract.
     * @param version An oracle versions.
     * @return oracleVersion The OracleVersion for the specified oracle version.
     */
    function oracleVersion(
        IChromaticMarket market,
        uint256 version
    ) external view returns (IOracleProvider.OracleVersion memory) {
        return market.oracleProvider().atVersion(version);
    }

    /**
     * @dev Retrieves the LP receipts for the specified owner in the given Chromatic market.
     * @param market The address of the Chromatic market contract.
     * @param owner The address of the LP token owner.
     * @return result An array of LpReceipt containing the LP receipts for the owner.
     */
    function lpReceipts(
        IChromaticMarket market,
        address owner
    ) public view returns (LpReceipt[] memory result) {
        uint256[] memory receiptIds = router.getLpReceiptIds(address(market), owner);

        result = new LpReceipt[](receiptIds.length);
        for (uint i; i < receiptIds.length; ) {
            //slither-disable-next-line calls-loop
            result[i] = market.getLpReceipt(receiptIds[i]);

            unchecked {
                i++;
            }
        }
    }

    /**
     * @dev Retrieves the CLB token balances for the specified owner in the given Chromatic market.
     * @param market The address of the Chromatic market contract.
     * @param owner The address of the CLB token owner.
     * @return An array of CLBBalance containing the CLB token balance information for the owner.
     */
    function clbBalanceOf(
        IChromaticMarket market,
        address owner
    ) external view returns (CLBBalance[] memory) {
        uint256[] memory tokenIds = CLBTokenLib.tokenIds();
        address[] memory accounts = new address[](tokenIds.length);
        // Set all accounts to the owner's address
        for (uint256 i; i < accounts.length; i++) {
            accounts[i] = owner;
        }

        // Get balances of CLB tokens for the owner
        uint256[] memory balances = market.clbToken().balanceOfBatch(accounts, tokenIds);

        // Count the number of CLB tokens with non-zero balance
        //slither-disable-next-line uninitialized-local
        uint256 effectiveCnt;
        for (uint256 i; i < balances.length; i++) {
            if (balances[i] != 0) {
                unchecked {
                    effectiveCnt++;
                }
            }
        }

        uint256[] memory effectiveBalances = new uint256[](effectiveCnt);
        uint256[] memory effectiveTokenIds = new uint256[](effectiveCnt);
        int16[] memory effectiveFeeRates = new int16[](effectiveCnt);

        //slither-disable-next-line uninitialized-local
        uint256 idx;
        for (uint256 i; i < balances.length; i++) {
            if (balances[i] != 0) {
                effectiveBalances[idx] = balances[i];
                effectiveTokenIds[idx] = tokenIds[i];
                effectiveFeeRates[idx] = CLBTokenLib.decodeId(tokenIds[i]);
                unchecked {
                    idx++;
                }
            }
        }

        uint256[] memory totalSupplies = market.clbToken().totalSupplyBatch(effectiveTokenIds);
        uint256[] memory binValues = market.getBinValues(effectiveFeeRates);

        // Populate the result array with CLB token balance information
        CLBBalance[] memory result = new CLBBalance[](effectiveCnt);
        for (uint256 i; i < effectiveCnt; i++) {
            result[i] = CLBBalance({
                tokenId: effectiveTokenIds[i],
                balance: effectiveBalances[i],
                totalSupply: totalSupplies[i],
                binValue: binValues[i]
            });
        }

        return result;
    }

    /**
     * @dev Retrieves the pending liquidity information for a specific trading fee rate in the given Chromatic market.
     * @param market The Chromatic market from which to retrieve the pending liquidity information.
     * @param tradingFeeRate The trading fee rate for which to retrieve the pending liquidity.
     * @return pendingLiquidity An instance of IChromaticMarket.PendingLiquidity representing the pending liquidity information.
     */
    function pendingLiquidity(
        IChromaticMarket market,
        int16 tradingFeeRate
    ) external view returns (IChromaticMarket.PendingLiquidity memory) {
        return market.pendingLiquidity(tradingFeeRate);
    }

    /**
     * @dev Retrieves the pending liquidity information for a list of trading fee rates in the given Chromatic market.
     * @param market The Chromatic market from which to retrieve the pending liquidity information.
     * @param tradingFeeRates The list of trading fee rates for which to retrieve the pending liquidity.
     * @return pendingLiquidityList An array of IChromaticMarket.PendingLiquidity representing the pending liquidity information for each trading fee rate.
     */
    function pendingLiquidityBatch(
        IChromaticMarket market,
        int16[] calldata tradingFeeRates
    ) external view returns (IChromaticMarket.PendingLiquidity[] memory) {
        return market.pendingLiquidityBatch(tradingFeeRates);
    }

    /**
     * @dev Retrieves the claimable liquidity information for a specific trading fee rate and oracle version from the given Chromatic Market.
     * @param market The Chromatic Market from which to retrieve the claimable liquidity information.
     * @param tradingFeeRate The trading fee rate for which to retrieve the claimable liquidity.
     * @param _oracleVersion The oracle version for which to retrieve the claimable liquidity.
     * @return claimableLiquidity An instance of IChromaticMarket.ClaimableLiquidity representing the claimable liquidity information.
     */
    function claimableLiquidity(
        IChromaticMarket market,
        int16 tradingFeeRate,
        uint256 _oracleVersion
    ) external view returns (IChromaticMarket.ClaimableLiquidity memory) {
        return market.claimableLiquidity(tradingFeeRate, _oracleVersion);
    }

    /**
     * @dev Retrieves the claimable liquidity information for a list of trading fee rates and a specific oracle version from the given Chromatic Market.
     * @param market The Chromatic Market from which to retrieve the claimable liquidity information.
     * @param tradingFeeRates The list of trading fee rates for which to retrieve the claimable liquidity.
     * @param _oracleVersion The oracle version for which to retrieve the claimable liquidity.
     * @return claimableLiquidityList An array of IChromaticMarket.ClaimableLiquidity representing the claimable liquidity information for each trading fee rate and the oracle version.
     */
    function claimableLiquidityBatch(
        IChromaticMarket market,
        int16[] calldata tradingFeeRates,
        uint256 _oracleVersion
    ) external view returns (IChromaticMarket.ClaimableLiquidity[] memory) {
        return market.claimableLiquidityBatch(tradingFeeRates, _oracleVersion);
    }

    /**
     * @dev Retrieves the liquidity bin statuses for the specified Chromatic Market.
     * @param market The Chromatic Market contract for which liquidity bin statuses are retrieved.
     * @return statuses An array of LiquidityBinStatus representing the liquidity bin statuses.
     */
    function liquidityBinStatuses(
        IChromaticMarket market
    ) external view returns (IChromaticMarket.LiquidityBinStatus[] memory) {
        return market.liquidityBinStatuses();
    }
}
