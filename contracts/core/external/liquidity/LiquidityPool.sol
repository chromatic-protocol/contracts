// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {ILiquidity} from "@chromatic/core/interfaces/market/ILiquidity.sol";
import {LiquidityBin, LiquidityBinLib} from "@chromatic/core/external/liquidity/LiquidityBin.sol";
import {PositionParam} from "@chromatic/core/external/liquidity/PositionParam.sol";
import {Position} from "@chromatic/core/libraries/Position.sol";
import {LpContext} from "@chromatic/core/libraries/LpContext.sol";
import {BinMargin} from "@chromatic/core/libraries/BinMargin.sol";
import {Errors} from "@chromatic/core/libraries/Errors.sol";

/**
 * @title LiquidityPool
 * @notice Represents a collection of long and short liquidity bins
 */
struct LiquidityPool {
    mapping(uint16 => LiquidityBin) _longBins;
    mapping(uint16 => LiquidityBin) _shortBins;
}

using LiquidityPoolLib for LiquidityPool global;

/**
 * @title LiquidityPoolLib
 * @notice Library for managing liquidity bins in an LiquidityPool
 */
library LiquidityPoolLib {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;
    using LiquidityBinLib for LiquidityBin;

    /**
     * @notice Emitted when earning is accumulated for a liquidity bin.
     * @param feeRate The fee rate of the bin.
     * @param binType The type of the bin ("L" for long, "S" for short).
     * @param earning The accumulated earning.
     */
    event LiquidityBinEarningAccumulated(
        uint16 indexed feeRate,
        bytes1 indexed binType,
        uint256 indexed earning
    );

    uint256 private constant FEE_RATES_LENGTH = 36;
    uint16 private constant MIN_FEE_RATE = 1;

    struct _proportionalPositionParamValue {
        int256 leveragedQty;
        uint256 takerMargin;
    }

    /**
     * @notice Modifier to validate the trading fee rate.
     * @param tradingFeeRate The trading fee rate to validate.
     */
    modifier _validTradingFeeRate(int16 tradingFeeRate) {
        validateTradingFeeRate(tradingFeeRate);

        _;
    }

    /**
     * @notice Initializes the LiquidityPool.
     * @param self The reference to the LiquidityPool.
     */
    function initialize(LiquidityPool storage self) external {
        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates = tradingFeeRates();
        for (uint256 i = 0; i < FEE_RATES_LENGTH; i++) {
            uint16 feeRate = _tradingFeeRates[i];
            self._longBins[feeRate].initialize(int16(feeRate));
            self._shortBins[feeRate].initialize(-int16(feeRate));
        }
    }

    /**
     * @notice Settles the liquidity bins in the LiquidityPool.
     * @param self The reference to the LiquidityPool.
     * @param ctx The LpContext object.
     */
    function settle(LiquidityPool storage self, LpContext memory ctx) external {
        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates = tradingFeeRates();
        for (uint256 i = 0; i < FEE_RATES_LENGTH; i++) {
            uint16 feeRate = _tradingFeeRates[i];
            self._longBins[feeRate].settle(ctx);
            self._shortBins[feeRate].settle(ctx);
        }
    }

    /**
     * @notice Prepares bin margins based on the given quantity and maker margin.
     * @dev This function prepares bin margins by performing the following steps:
     *      1. Calculates the appropriate bin margins
     *         for each trading fee rate based on the provided quantity and maker margin.
     *      2. Iterates through the target bins based on the quantity,
     *         finds the minimum available fee rate,
     *         and determines the upper bound for calculating bin margins.
     *      3. Iterates from the minimum fee rate until the upper bound,
     *         assigning the remaining maker margin to the bins until it is exhausted.
     *      4. Creates an array of BinMargin structs
     *         containing the trading fee rate and corresponding margin amount for each bin.
     * @param self The reference to the LiquidityPool.
     * @param qty The quantity of the position.
     * @param makerMargin The maker margin of the position.
     * @return binMargins An array of BinMargin representing the calculated bin margins.
     */
    function prepareBinMargins(
        LiquidityPool storage self,
        int224 qty,
        uint256 makerMargin
    ) external view returns (BinMargin[] memory) {
        // Retrieve the target liquidity bins based on the position quantity
        mapping(uint16 => LiquidityBin) storage _bins = targetBins(self, qty);

        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates = tradingFeeRates();
        uint256[FEE_RATES_LENGTH] memory _binMargins;

        uint256 to;
        uint256 cnt;
        uint256 remain = makerMargin;
        for (; to < FEE_RATES_LENGTH; to++) {
            if (remain == 0) break;

            uint256 freeLiquidity = _bins[_tradingFeeRates[to]].freeLiquidity();
            if (freeLiquidity > 0) {
                if (remain <= freeLiquidity) {
                    _binMargins[to] = remain;
                    remain = 0;
                } else {
                    _binMargins[to] = freeLiquidity;
                    remain -= freeLiquidity;
                }
                cnt++;
            }
        }

        require(remain == 0, Errors.NOT_ENOUGH_FREE_LIQUIDITY);

        BinMargin[] memory binMargins = new BinMargin[](cnt);
        for ((uint256 i, uint256 idx) = (0, 0); i < to; i++) {
            if (_binMargins[i] > 0) {
                binMargins[idx] = BinMargin({
                    tradingFeeRate: _tradingFeeRates[i],
                    amount: _binMargins[i]
                });
                unchecked {
                    idx++;
                }
            }
        }

        return binMargins;
    }

    /**
     * @notice Accepts an open position and opens corresponding liquidity bins.
     * @dev This function calculates the target liquidity bins based on the position quantity.
     *      It prepares the bin margins and divides the position parameters accordingly.
     *      Then, it opens the liquidity bins with the corresponding parameters and trading fees.
     * @param self The reference to the LiquidityPool storage.
     * @param ctx The LpContext object.
     * @param position The Position object representing the open position.
     */
    function acceptOpenPosition(
        LiquidityPool storage self,
        LpContext memory ctx,
        Position memory position
    ) external {
        // Retrieve the target liquidity bins based on the position quantity
        mapping(uint16 => LiquidityBin) storage _bins = targetBins(self, position.qty);

        uint256 makerMargin = position.makerMargin();
        BinMargin[] memory binMargins = position.binMargins();

        // Divide the position parameters to match the bin margins
        _proportionalPositionParamValue[] memory paramValues = divideToPositionParamValue(
            position.leveragedQty(ctx),
            makerMargin,
            position.takerMargin,
            binMargins
        );

        PositionParam memory param = newPositionParam(position.openVersion, position.openTimestamp);
        for (uint256 i = 0; i < binMargins.length; i++) {
            BinMargin memory binMargin = binMargins[i];

            if (binMargin.amount > 0) {
                param.leveragedQty = paramValues[i].leveragedQty;
                param.takerMargin = paramValues[i].takerMargin;
                param.makerMargin = binMargin.amount;

                _bins[binMargins[i].tradingFeeRate].openPosition(
                    ctx,
                    param,
                    binMargin.tradingFee()
                );
            }
        }
    }

    /**
     * @notice Accepts a close position request and closes the corresponding liquidity bins.
     * @dev This function calculates the target liquidity bins based on the position quantity.
     *      It retrieves the maker margin and bin margins from the position.
     *      Then, it divides the position parameters to match the bin margins.
     *      Finally, it closes the liquidity bins with the provided parameters.
     * @param self The reference to the LiquidityPool storage.
     * @param ctx The LpContext object.
     * @param position The Position object representing the close position request.
     */
    function acceptClosePosition(
        LiquidityPool storage self,
        LpContext memory ctx,
        Position memory position
    ) external {
        // Retrieve the target liquidity bins based on the position quantity
        mapping(uint16 => LiquidityBin) storage _bins = targetBins(self, position.qty);

        uint256 makerMargin = position.makerMargin();
        BinMargin[] memory binMargins = position.binMargins();

        // Divide the position parameters to match the bin margins
        _proportionalPositionParamValue[] memory paramValues = divideToPositionParamValue(
            position.leveragedQty(ctx),
            makerMargin,
            position.takerMargin,
            binMargins
        );

        PositionParam memory param = newPositionParam(
            position.openVersion,
            position.closeVersion,
            position.openTimestamp,
            position.closeTimestamp
        );

        for (uint256 i = 0; i < binMargins.length; i++) {
            if (binMargins[i].amount > 0) {
                LiquidityBin storage _bin = _bins[binMargins[i].tradingFeeRate];

                param.leveragedQty = paramValues[i].leveragedQty;
                param.takerMargin = paramValues[i].takerMargin;
                param.makerMargin = binMargins[i].amount;

                _bin.closePosition(ctx, param);
            }
        }
    }

    /**
     * @notice Accepts a claim position request and processes the corresponding liquidity bins
     *         based on the realized position pnl.
     * @dev This function verifies if the absolute value of the realized position pnl is within the acceptable margin range.
     *      It retrieves the target liquidity bins based on the position quantity and the bin margins from the position.
     *      Then, it divides the position parameters to match the bin margins.
     *      Depending on the value of the realized position pnl, it either claims the position fully or partially.
     *      The claimed pnl is distributed among the liquidity bins according to their respective margins.
     * @param self The reference to the LiquidityPool storage.
     * @param ctx The LpContext object.
     * @param position The Position object representing the position to claim.
     * @param realizedPnl The realized position pnl (taker side).
     */
    function acceptClaimPosition(
        LiquidityPool storage self,
        LpContext memory ctx,
        Position memory position,
        int256 realizedPnl // realized position pnl (taker side)
    ) external {
        uint256 absRealizedPnl = realizedPnl.abs();
        uint256 makerMargin = position.makerMargin();
        // Ensure that the realized position pnl is within the acceptable margin range
        require(
            !((realizedPnl > 0 && absRealizedPnl > makerMargin) ||
                (realizedPnl < 0 && absRealizedPnl > position.takerMargin)),
            Errors.EXCEED_MARGIN_RANGE
        );

        // Retrieve the target liquidity bins based on the position quantity
        mapping(uint16 => LiquidityBin) storage _bins = targetBins(self, position.qty);
        BinMargin[] memory binMargins = position.binMargins();

        // Divide the position parameters to match the bin margins
        _proportionalPositionParamValue[] memory paramValues = divideToPositionParamValue(
            position.leveragedQty(ctx),
            makerMargin,
            position.takerMargin,
            binMargins
        );

        PositionParam memory param = newPositionParam(
            position.openVersion,
            position.closeVersion,
            position.openTimestamp,
            position.closeTimestamp
        );

        if (realizedPnl == 0) {
            for (uint256 i = 0; i < binMargins.length; i++) {
                if (binMargins[i].amount > 0) {
                    LiquidityBin storage _bin = _bins[binMargins[i].tradingFeeRate];

                    param.leveragedQty = paramValues[i].leveragedQty;
                    param.takerMargin = paramValues[i].takerMargin;
                    param.makerMargin = binMargins[i].amount;

                    _bin.claimPosition(ctx, param, 0);
                }
            }
        } else if (realizedPnl > 0 && absRealizedPnl == makerMargin) {
            for (uint256 i = 0; i < binMargins.length; i++) {
                if (binMargins[i].amount > 0) {
                    LiquidityBin storage _bin = _bins[binMargins[i].tradingFeeRate];

                    param.leveragedQty = paramValues[i].leveragedQty;
                    param.takerMargin = paramValues[i].takerMargin;
                    param.makerMargin = binMargins[i].amount;

                    _bin.claimPosition(ctx, param, param.makerMargin.toInt256());
                }
            }
        } else {
            uint256 remainMakerMargin = makerMargin;
            uint256 remainRealizedPnl = absRealizedPnl;

            for (uint256 i = 0; i < binMargins.length; i++) {
                if (binMargins[i].amount > 0) {
                    LiquidityBin storage _bin = _bins[binMargins[i].tradingFeeRate];

                    param.leveragedQty = paramValues[i].leveragedQty;
                    param.takerMargin = paramValues[i].takerMargin;
                    param.makerMargin = binMargins[i].amount;

                    uint256 absTakerPnl = remainRealizedPnl.mulDiv(
                        param.makerMargin,
                        remainMakerMargin
                    );
                    if (realizedPnl < 0) {
                        // maker profit
                        absTakerPnl = Math.min(absTakerPnl, param.takerMargin);
                    } else {
                        // taker profit
                        absTakerPnl = Math.min(absTakerPnl, param.makerMargin);
                    }

                    int256 takerPnl = realizedPnl < 0
                        ? -(absTakerPnl.toInt256())
                        : absTakerPnl.toInt256();

                    _bin.claimPosition(ctx, param, takerPnl);

                    remainMakerMargin -= param.makerMargin;
                    remainRealizedPnl -= absTakerPnl;
                }
            }

            require(remainRealizedPnl == 0, Errors.EXCEED_MARGIN_RANGE);
        }
    }

    /**
     * @notice Accepts an add liquidity request
     *         and processes the liquidity bin corresponding to the given trading fee rate.
     * @dev This function validates the trading fee rate
     *      and calls the acceptAddLiquidity function on the target liquidity bin.
     * @param self The reference to the LiquidityPool storage.
     * @param ctx The LpContext object.
     * @param tradingFeeRate The trading fee rate associated with the liquidity bin.
     * @param amount The amount of liquidity to add.
     */
    function acceptAddLiquidity(
        LiquidityPool storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 amount
    ) external _validTradingFeeRate(tradingFeeRate) {
        // Retrieve the liquidity bin based on the trading fee rate
        LiquidityBin storage bin = targetBin(self, tradingFeeRate);
        // Process the add liquidity request on the liquidity bin
        bin.acceptAddLiquidity(ctx, amount);
    }

    /**
     * @notice Accepts a claim liquidity request
     *         and processes the liquidity bin corresponding to the given trading fee rate.
     * @dev This function validates the trading fee rate
     *      and calls the acceptClaimLiquidity function on the target liquidity bin.
     * @param self The reference to the LiquidityPool storage.
     * @param ctx The LpContext object.
     * @param tradingFeeRate The trading fee rate associated with the liquidity bin.
     * @param amount The amount of liquidity to claim.
     *        (should be the same as the one used in acceptAddLiquidity)
     * @param oracleVersion The oracle version used for the claim.
     *        (should be the oracle version when call acceptAddLiquidity)
     * @return The amount of liquidity (CLB tokens) received as a result of the liquidity claim.
     */
    function acceptClaimLiquidity(
        LiquidityPool storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 amount,
        uint256 oracleVersion
    ) external _validTradingFeeRate(tradingFeeRate) returns (uint256) {
        // Retrieve the liquidity bin based on the trading fee rate
        LiquidityBin storage bin = targetBin(self, tradingFeeRate);
        // Process the claim liquidity request on the liquidity bin and return the actual claimed amount
        return bin.acceptClaimLiquidity(ctx, amount, oracleVersion);
    }

    /**
     * @notice Accepts a remove liquidity request
     *         and processes the liquidity bin corresponding to the given trading fee rate.
     * @dev This function validates the trading fee rate
     *      and calls the acceptRemoveLiquidity function on the target liquidity bin.
     * @param self The reference to the LiquidityPool storage.
     * @param ctx The LpContext object.
     * @param tradingFeeRate The trading fee rate associated with the liquidity bin.
     * @param clbTokenAmount The amount of CLB tokens to remove.
     */
    function acceptRemoveLiquidity(
        LiquidityPool storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 clbTokenAmount
    ) external _validTradingFeeRate(tradingFeeRate) {
        // Retrieve the liquidity bin based on the trading fee rate
        LiquidityBin storage bin = targetBin(self, tradingFeeRate);
        // Process the remove liquidity request on the liquidity bin
        bin.acceptRemoveLiquidity(ctx, clbTokenAmount);
    }

    /**
     * @notice Accepts a withdraw liquidity request
     *         and processes the liquidity bin corresponding to the given trading fee rate.
     * @dev This function validates the trading fee rate
     *      and calls the acceptWithdrawLiquidity function on the target liquidity bin.
     * @param self The reference to the LiquidityPool storage.
     * @param ctx The LpContext object.
     * @param tradingFeeRate The trading fee rate associated with the liquidity bin.
     * @param clbTokenAmount The amount of CLB tokens to withdraw.
     *        (should be the same as the one used in acceptRemoveLiquidity)
     * @param oracleVersion The oracle version used for the withdrawal.
     *        (should be the oracle version when call acceptRemoveLiquidity)
     * @return amount The amount of base tokens withdrawn
     * @return burnedCLBTokenAmount the amount of CLB tokens burned.
     */
    function acceptWithdrawLiquidity(
        LiquidityPool storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 clbTokenAmount,
        uint256 oracleVersion
    )
        external
        _validTradingFeeRate(tradingFeeRate)
        returns (uint256 amount, uint256 burnedCLBTokenAmount)
    {
        // Retrieve the liquidity bin based on the trading fee rate
        LiquidityBin storage bin = targetBin(self, tradingFeeRate);
        // Process the withdraw liquidity request on the liquidity bin
        // and get the amount of base tokens withdrawn and CLB tokens burned
        return bin.acceptWithdrawLiquidity(ctx, clbTokenAmount, oracleVersion);
    }

    /**
     * @notice Calculates the amount of CLB tokens to be minted for the given amount of base tokens and trading fee rate.
     * @dev This function validates the trading fee rate
     *      and calls the calculateCLBTokenMinting function on the target liquidity bin.
     * @param self The reference to the LiquidityPool storage.
     * @param ctx The LpContext object.
     * @param tradingFeeRate The trading fee rate associated with the liquidity bin.
     * @param amount The amount of base tokens.
     * @return The amount of CLB tokens to be minted.
     */
    function calculateCLBTokenMinting(
        LiquidityPool storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 amount
    ) external view _validTradingFeeRate(tradingFeeRate) returns (uint256) {
        // Retrieve the liquidity bin based on the trading fee rate
        LiquidityBin storage bin = targetBin(self, tradingFeeRate);
        // Calculate the amount of CLB tokens to be minted based on the given amount of base tokens
        return bin.calculateCLBTokenMinting(ctx, amount);
    }

    /**
     * @notice Calculates the value of the given amount of CLB tokens for the specified trading fee rate.
     * @dev This function validates the trading fee rate
     *      and calls the calculateCLBTokenValue function on the target liquidity bin.
     * @param self The reference to the LiquidityPool storage.
     * @param ctx The LpContext object.
     * @param tradingFeeRate The trading fee rate associated with the liquidity bin.
     * @param clbTokenAmount The amount of CLB tokens.
     * @return amount The value of the CLB tokens in base tokens.
     */
    function calculateCLBTokenValue(
        LiquidityPool storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 clbTokenAmount
    ) external view _validTradingFeeRate(tradingFeeRate) returns (uint256 amount) {
        // Retrieve the liquidity bin based on the trading fee rate
        LiquidityBin storage bin = targetBin(self, tradingFeeRate);
        // Calculate the value of the given amount of CLB tokens in base tokens
        amount = bin.calculateCLBTokenValue(ctx, clbTokenAmount);
    }

    /**
     * @notice Retrieves the total liquidity amount in base tokens for the specified trading fee rate.
     * @dev This function retrieves the liquidity bin based on the trading fee rate
     *      and calls the liquidity function on it.
     * @param self The reference to the LiquidityPool storage.
     * @param tradingFeeRate The trading fee rate associated with the liquidity bin.
     * @return amount The total liquidity amount in base tokens.
     */
    function getBinLiquidity(
        LiquidityPool storage self,
        int16 tradingFeeRate
    ) external view returns (uint256 amount) {
        // Retrieve the liquidity bin based on the trading fee rate
        LiquidityBin storage bin = targetBin(self, tradingFeeRate);
        // Get the total liquidity amount in base tokens from the liquidity bin
        return bin.liquidity();
    }

    /**
     * @notice Retrieves the free liquidity amount in base tokens for the specified trading fee rate.
     * @dev This function retrieves the liquidity bin based on the trading fee rate
     *      and calls the freeLiquidity function on it.
     * @param self The reference to the LiquidityPool storage.
     * @param tradingFeeRate The trading fee rate associated with the liquidity bin.
     * @return amount The free liquidity amount in base tokens.
     */
    function getBinFreeLiquidity(
        LiquidityPool storage self,
        int16 tradingFeeRate
    ) external view returns (uint256 amount) {
        // Retrieve the liquidity bin based on the trading fee rate
        LiquidityBin storage bin = targetBin(self, tradingFeeRate);
        // Get the free liquidity amount in base tokens from the liquidity bin
        return bin.freeLiquidity();
    }

    /**
     * @notice Retrieves the target bins based on the sign of the given value.
     * @dev This function retrieves the target bins mapping (short or long) based on the sign of the given value.
     * @param self The storage reference to the LiquidityPool.
     * @param sign The sign of the value (-1 for negative, 1 for positive).
     * @return _bins The target bins mapping associated with the sign of the value.
     */
    function targetBins(
        LiquidityPool storage self,
        int256 sign
    ) private view returns (mapping(uint16 => LiquidityBin) storage) {
        return sign < 0 ? self._shortBins : self._longBins;
    }

    /**
     * @notice Retrieves the target bin based on the trading fee rate.
     * @dev This function retrieves the target bin based on the sign of the trading fee rate and returns it.
     * @param self The storage reference to the LiquidityPool.
     * @param tradingFeeRate The trading fee rate associated with the bin.
     * @return bin The target bin associated with the trading fee rate.
     */
    function targetBin(
        LiquidityPool storage self,
        int16 tradingFeeRate
    ) private view returns (LiquidityBin storage) {
        return
            tradingFeeRate < 0
                ? self._shortBins[abs(tradingFeeRate)]
                : self._longBins[abs(tradingFeeRate)];
    }

    /**
     * @notice Divides the leveraged quantity, maker margin, and taker margin
     *         into proportional position parameter values.
     * @dev This function divides the leveraged quantity, maker margin, and taker margin
     *      into proportional position parameter values based on the bin margins.
     *      It calculates the proportional values for each bin margin and returns them in an array.
     * @param leveragedQty The leveraged quantity.
     * @param makerMargin The maker margin amount.
     * @param takerMargin The taker margin amount.
     * @param binMargins The array of bin margins.
     * @return values The array of proportional position parameter values.
     */
    function divideToPositionParamValue(
        int256 leveragedQty,
        uint256 makerMargin,
        uint256 takerMargin,
        BinMargin[] memory binMargins
    ) private pure returns (_proportionalPositionParamValue[] memory) {
        uint256 remainLeveragedQty = leveragedQty.abs();
        uint256 remainTakerMargin = takerMargin;

        _proportionalPositionParamValue[] memory values = new _proportionalPositionParamValue[](
            binMargins.length
        );

        for (uint256 i = 0; i < binMargins.length - 1; i++) {
            uint256 _qty = remainLeveragedQty.mulDiv(binMargins[i].amount, makerMargin);
            uint256 _takerMargin = remainTakerMargin.mulDiv(binMargins[i].amount, makerMargin);

            values[i] = _proportionalPositionParamValue({
                leveragedQty: leveragedQty < 0 ? _qty.toInt256() : -(_qty.toInt256()), // opposit side
                takerMargin: _takerMargin
            });

            remainLeveragedQty -= _qty;
            remainTakerMargin -= _takerMargin;
        }

        values[binMargins.length - 1] = _proportionalPositionParamValue({
            leveragedQty: leveragedQty < 0
                ? remainLeveragedQty.toInt256()
                : -(remainLeveragedQty.toInt256()), // opposit side
            takerMargin: remainTakerMargin
        });

        return values;
    }

    /**
     * @notice Creates a new PositionParam struct with the given oracle version and timestamp.
     * @param openVersion The version of the oracle when the position was opened
     * @param openTimestamp The timestamp when the position was opened
     * @return param The new PositionParam struct.
     */
    function newPositionParam(
        uint256 openVersion,
        uint256 openTimestamp
    ) private pure returns (PositionParam memory param) {
        param.openVersion = openVersion;
        param.openTimestamp = openTimestamp;
    }

    /**
     * @notice Creates a new PositionParam struct with the given oracle version and timestamp.
     * @param openVersion The version of the oracle when the position was opened
     * @param closeVersion The version of the oracle when the position was closed
     * @param openTimestamp The timestamp when the position was opened
     * @param closeTimestamp The timestamp when the position was closed
     * @return param The new PositionParam struct.
     */
    function newPositionParam(
        uint256 openVersion,
        uint256 closeVersion,
        uint256 openTimestamp,
        uint256 closeTimestamp
    ) private pure returns (PositionParam memory param) {
        param.openVersion = openVersion;
        param.closeVersion = closeVersion;
        param.openTimestamp = openTimestamp;
        param.closeTimestamp = closeTimestamp;
    }

    /**
     * @notice Validates the trading fee rate.
     * @dev This function validates the trading fee rate by checking if it is supported.
     *      It compares the absolute value of the fee rate with the predefined trading fee rates
     *      to determine if it is a valid rate.
     * @param tradingFeeRate The trading fee rate to be validated.
     */
    function validateTradingFeeRate(int16 tradingFeeRate) private pure {
        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates = tradingFeeRates();

        uint16 absFeeRate = abs(tradingFeeRate);

        uint256 idx = findUpperBound(_tradingFeeRates, absFeeRate);
        require(
            idx < _tradingFeeRates.length && absFeeRate == _tradingFeeRates[idx],
            Errors.UNSUPPORTED_TRADING_FEE_RATE
        );
    }

    /**
     * @notice Calculates the absolute value of an int16 number.
     * @param i The int16 number.
     * @return absValue The absolute value of the input number.
     */
    function abs(int16 i) private pure returns (uint16) {
        return i < 0 ? uint16(-i) : uint16(i);
    }

    /**
     * @notice Retrieves the array of supported trading fee rates.
     * @dev This function returns the array of supported trading fee rates,
     *      ranging from the minimum fee rate to the maximum fee rate with step increments.
     * @return tradingFeeRates The array of supported trading fee rates.
     */
    function tradingFeeRates() private pure returns (uint16[FEE_RATES_LENGTH] memory) {
        // prettier-ignore
        return [
            MIN_FEE_RATE, 2, 3, 4, 5, 6, 7, 8, 9, // 0.01% ~ 0.09%, step 0.01%
            10, 20, 30, 40, 50, 60, 70, 80, 90, // 0.1% ~ 0.9%, step 0.1%
            100, 200, 300, 400, 500, 600, 700, 800, 900, // 1% ~ 9%, step 1%
            1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000 // 10% ~ 50%, step 5%
        ];
    }

    /**
     * @notice Finds the upper bound index of an element in a sorted array.
     * @dev This function performs a binary search on the sorted array
     *      to find * the index of the upper bound of the given element.
     *      It returns the index as the exclusive upper bound,
     *      or the inclusive upper bound if the element is found at the end of the array.
     * @param array The sorted array.
     * @param element The element to find the upper bound for.
     * @return uint256 The index of the upper bound of the element in the array.
     */
    function findUpperBound(
        uint16[FEE_RATES_LENGTH] memory array,
        uint16 element
    ) private pure returns (uint256) {
        if (array.length == 0) {
            return 0;
        }

        uint256 low = 0;
        uint256 high = array.length;

        while (low < high) {
            uint256 mid = Math.average(low, high);

            // Note that mid will always be strictly less than high (i.e. it will be a valid array index)
            // because Math.average rounds down (it does integer division with truncation).
            if (array[mid] > element) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        // At this point `low` is the exclusive upper bound. We will return the inclusive upper bound.
        if (low > 0 && array[low - 1] == element) {
            return low - 1;
        } else {
            return low;
        }
    }

    /**
     * @notice Distributes earnings among the liquidity bins.
     * @dev This function distributes the earnings among the liquidity bins,
     *      proportional to their total balances.
     *      It iterates through the trading fee rates
     *      and distributes the proportional amount of earnings to each bin
     *      based on its total balance relative to the market balance.
     * @param self The LiquidityPool storage.
     * @param earning The total earnings to be distributed.
     * @param marketBalance The market balance.
     */
    function distributeEarning(
        LiquidityPool storage self,
        uint256 earning,
        uint256 marketBalance
    ) external {
        uint256 remainEarning = earning;
        uint256 remainBalance = marketBalance;
        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates = tradingFeeRates();

        (remainEarning, remainBalance) = distributeEarning(
            self._longBins,
            remainEarning,
            remainBalance,
            _tradingFeeRates,
            "L"
        );
        (remainEarning, remainBalance) = distributeEarning(
            self._shortBins,
            remainEarning,
            remainBalance,
            _tradingFeeRates,
            "S"
        );
    }

    /**
     * @notice Distributes earnings among the liquidity bins of a specific type.
     * @dev This function distributes the earnings among the liquidity bins of
     *      the specified type, proportional to their total balances.
     *      It iterates through the trading fee rates
     *      and distributes the proportional amount of earnings to each bin
     *      based on its total balance relative to the market balance.
     * @param bins The liquidity bins mapping.
     * @param earning The total earnings to be distributed.
     * @param marketBalance The market balance.
     * @param _tradingFeeRates The array of supported trading fee rates.
     * @param binType The type of liquidity bin ("L" for long, "S" for short).
     * @return remainEarning The remaining earnings after distribution.
     * @return remainBalance The remaining market balance after distribution.
     */
    function distributeEarning(
        mapping(uint16 => LiquidityBin) storage bins,
        uint256 earning,
        uint256 marketBalance,
        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates,
        bytes1 binType
    ) private returns (uint256 remainEarning, uint256 remainBalance) {
        remainBalance = marketBalance;
        remainEarning = earning;

        for (uint256 i = 0; i < FEE_RATES_LENGTH; i++) {
            uint16 feeRate = _tradingFeeRates[i];
            LiquidityBin storage bin = bins[feeRate];
            uint256 binLiquidity = bin.liquidity();

            if (binLiquidity == 0) continue;

            uint256 binEarning = remainEarning.mulDiv(binLiquidity, remainBalance);

            bin.applyEarning(binEarning);

            remainBalance -= binLiquidity;
            remainEarning -= binEarning;

            emit LiquidityBinEarningAccumulated(feeRate, binType, binEarning);
        }
    }

    function slotValues(
        LpSlotSet storage self,
        int16[] calldata _tradingFeeRates,
        LpContext memory ctx
    ) external view returns (uint256[] memory values) {
        values = new uint256[](_tradingFeeRates.length);
        for (uint i = 0; i < _tradingFeeRates.length; i++) {
            values[i] = targetSlot(self, _tradingFeeRates[i]).value(ctx);
        }
    }

    function getClaimBurning(
        LpSlotSet storage self,
        int16 tradingFeeRate,
        uint256 oracleVersion
    )
        external
        view
        _validTradingFeeRate(tradingFeeRate)
        returns (uint256 lpTokenAmount, uint256 burningAmount, uint256 tokenAmount)
    {
        LpSlot storage slot = targetSlot(self, tradingFeeRate);
        return slot.getClaimBurning(oracleVersion);
    }
}
