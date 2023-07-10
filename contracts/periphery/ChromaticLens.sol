// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
// import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Fixed18, UFixed18, Fixed18Lib} from "@equilibria/root/number/types/Fixed18.sol";
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

    IChromaticRouter router;

    constructor(IChromaticRouter _router) {
        router = _router;
    }

    function multicall(bytes[] calldata data) external view returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i; i < data.length; ) {
            results[i] = Address.functionStaticCall(address(this), data[i]);

            unchecked {
                i++;
            }
        }
        return results;
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
        for (uint256 i; i < accounts.length; ) {
            accounts[i] = owner;

            unchecked {
                i++;
            }
        }

        // Get balances of CLB tokens for the owner
        uint256[] memory balances = market.clbToken().balanceOfBatch(accounts, tokenIds);

        // Count the number of CLB tokens with non-zero balance
        uint256 effectiveCnt;
        for (uint256 i; i < balances.length; ) {
            if (balances[i] != 0) {
                unchecked {
                    effectiveCnt++;
                }
            }

            unchecked {
                i++;
            }
        }

        uint256[] memory effectiveBalances = new uint256[](effectiveCnt);
        uint256[] memory effectiveTokenIds = new uint256[](effectiveCnt);
        int16[] memory effectiveFeeRates = new int16[](effectiveCnt);

        uint256 idx;
        for (uint256 i; i < balances.length; ) {
            if (balances[i] != 0) {
                effectiveBalances[idx] = balances[i];
                effectiveTokenIds[idx] = tokenIds[i];
                effectiveFeeRates[idx] = CLBTokenLib.decodeId(tokenIds[i]);
                unchecked {
                    idx++;
                }
            }

            unchecked {
                i++;
            }
        }

        uint256[] memory totalSupplies = market.clbToken().totalSupplyBatch(effectiveTokenIds);
        uint256[] memory binValues = market.getBinValues(effectiveFeeRates);

        // Populate the result array with CLB token balance information
        CLBBalance[] memory result = new CLBBalance[](effectiveCnt);
        for (uint256 i; i < effectiveCnt; ) {
            result[i] = CLBBalance({
                tokenId: effectiveTokenIds[i],
                balance: effectiveBalances[i],
                totalSupply: totalSupplies[i],
                binValue: binValues[i]
            });

            unchecked {
                i++;
            }
        }

        return result;
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
