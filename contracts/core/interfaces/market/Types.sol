// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

bytes4 constant CLAIM_USER = "UC";
bytes4 constant CLAIM_KEEPER = "KC";
bytes4 constant CLAIM_TP = "TP";
bytes4 constant CLAIM_SL = "SL";

enum PositionMode {
    Normal,
    OpenDisabled,
    CloseDisabled,
    Suspended
}

enum LiquidityMode {
    Normal,
    AddDisabled,
    RemoveDisabled,
    Suspended
}

enum DisplayMode {
    Normal,
    Suspended,
    Deprecating,
    Deprecated
}

/**
 * @dev The OpenPositionInfo struct represents a opened trading position.
 * @param id The position identifier
 * @param openVersion The version of the oracle when the position was opened
 * @param qty The quantity of the position
 * @param openTimestamp The timestamp when the position was opened
 * @param takerMargin The amount of collateral that a trader must provide
 * @param makerMargin The margin amount provided by the maker.
 * @param tradingFee The trading fee associated with the position.
 */
struct OpenPositionInfo {
    uint256 id;
    uint256 openVersion;
    int256 qty;
    uint256 openTimestamp;
    uint256 takerMargin;
    uint256 makerMargin;
    uint256 tradingFee;
}

/**
 * @dev The ClosePositionInfo struct represents a closed trading position.
 * @param id The position identifier
 * @param closeVersion The version of the oracle when the position was closed
 * @param closeTimestamp The timestamp when the position was closed
 */
struct ClosePositionInfo {
    uint256 id;
    uint256 closeVersion;
    uint256 closeTimestamp;
}

/**
 * @dev The ClaimPositionInfo struct represents a claimed position information.
 * @param id The position identifier
 * @param entryPrice The entry price of the position
 * @param exitPrice The exit price of the position
 * @param realizedPnl The profit or loss of the claimed position.
 * @param interest The interest paid for the claimed position.
 * @param cause The description of being claimed.
 */
struct ClaimPositionInfo {
    uint256 id;
    uint256 entryPrice;
    uint256 exitPrice;
    int256 realizedPnl;
    uint256 interest;
    bytes4 cause;
}

/**
 * @dev Represents a pending position within the LiquidityBin
 * @param openVersion The oracle version when the position was opened.
 * @param totalQty The total quantity of the pending position.
 * @param totalMakerMargin The total maker margin of the pending position.
 * @param totalTakerMargin The total taker margin of the pending position.
 */
struct PendingPosition {
    uint256 openVersion;
    int256 totalQty;
    uint256 totalMakerMargin;
    uint256 totalTakerMargin;
}

/**
 * @dev Represents the closing position within an LiquidityBin.
 * @param closeVersion The oracle version when the position was closed.
 * @param totalQty The total quantity of the closing position.
 * @param totalEntryAmount The total entry amount of the closing position.
 * @param totalMakerMargin The total maker margin of the closing position.
 * @param totalTakerMargin The total taker margin of the closing position.
 */
struct ClosingPosition {
    uint256 closeVersion;
    int256 totalQty;
    uint256 totalEntryAmount;
    uint256 totalMakerMargin;
    uint256 totalTakerMargin;
}

/**
 * @dev A struct representing pending liquidity information.
 * @param oracleVersion The oracle version of pending liqudity.
 * @param mintingTokenAmountRequested The amount of settlement tokens requested for minting.
 * @param burningCLBTokenAmountRequested The amount of CLB tokens requested for burning.
 */
struct PendingLiquidity {
    uint256 oracleVersion;
    uint256 mintingTokenAmountRequested;
    uint256 burningCLBTokenAmountRequested;
}

/**
 * @dev A struct representing claimable liquidity information.
 * @param mintingTokenAmountRequested The amount of settlement tokens requested for minting.
 * @param mintingCLBTokenAmount The actual amount of CLB tokens minted.
 * @param burningCLBTokenAmountRequested The amount of CLB tokens requested for burning.
 * @param burningCLBTokenAmount The actual amount of CLB tokens burned.
 * @param burningTokenAmount The amount of settlement tokens equal in value to the burned CLB tokens.
 */
struct ClaimableLiquidity {
    uint256 mintingTokenAmountRequested;
    uint256 mintingCLBTokenAmount;
    uint256 burningCLBTokenAmountRequested;
    uint256 burningCLBTokenAmount;
    uint256 burningTokenAmount;
}

/**
 * @dev A struct representing status of the liquidity bin.
 * @param liquidity The total liquidity amount in the bin
 * @param freeLiquidity The amount of free liquidity available in the bin.
 * @param binValue The current value of the bin.
 * @param tradingFeeRate The trading fee rate for the liquidity.
 */
struct LiquidityBinStatus {
    uint256 liquidity;
    uint256 freeLiquidity;
    uint256 binValue;
    int16 tradingFeeRate;
}
