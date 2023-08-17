// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {DoubleEndedQueue} from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";
import {IMarketLiquidity} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidity.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {Errors} from "@chromatic-protocol/contracts/core/libraries/Errors.sol";

/**
 * @dev Represents the liquidity information within an LiquidityBin.
 */
struct BinLiquidity {
    uint256 total;
    IMarketLiquidity.PendingLiquidity _pending;
    mapping(uint256 => _ClaimMinting) _claimMintings;
    mapping(uint256 => _ClaimBurning) _claimBurnings;
    DoubleEndedQueue.Bytes32Deque _burningVersions;
}

/**
 * @dev Represents the accumulated values of minting claims
 *      for a specific oracle version within BinLiquidity.
 */
struct _ClaimMinting {
    uint256 tokenAmountRequested;
    uint256 clbTokenAmount;
}

/**
 * @dev Represents the accumulated values of burning claims
 *      for a specific oracle version within BinLiquidity.
 */
struct _ClaimBurning {
    uint256 clbTokenAmountRequested;
    uint256 clbTokenAmount;
    uint256 tokenAmount;
}

/**
 * @title BinLiquidityLib
 * @notice A library that provides functions to manage the liquidity within an LiquidityBin.
 */
library BinLiquidityLib {
    using Math for uint256;
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

    /// @dev Minimum amount constant to prevent division by zero.
    uint256 private constant MIN_AMOUNT = 1000;

    /**
     * @notice Settles the pending liquidity within the BinLiquidity.
     * @dev This function settles pending liquidity in the BinLiquidity storage by performing the following steps:
     *      1. Settles pending liquidity
     *          - If the pending oracle version is not set or is greater than or equal to the current oracle version,
     *            no action is taken.
     *          - Otherwise, the pending liquidity and burning CLB tokens are settled by following steps:
     *              a. If there is a pending deposit,
     *                 it calculates the minting amount of CLB tokens
     *                 based on the pending deposit, bin value, and CLB token total supply.
     *                 It updates the total liquidity and adds the pending deposit to the claim mintings.
     *              b. If there is a pending CLB token burning,
     *                 it adds the oracle version to the burning versions list
     *                 and initializes the claim burning details.
     *      2. Settles bunding CLB tokens
     *          a. It trims all completed burning versions from the burning versions list.
     *          b. For each burning version in the list,
     *             it calculates the pending CLB token amount and the pending withdrawal amount
     *             based on the bin value and CLB token total supply.
     *             - If there is sufficient free liquidity, it calculates the burning amount of CLB tokens.
     *             - If there is insufficient free liquidity, it calculates the burning amount
     *               based on the available free liquidity and updates the pending withdrawal accordingly.
     *          c. It updates the burning amount and pending withdrawal,
     *             and reduces the free liquidity accordingly.
     *          d. Finally, it updates the total liquidity by subtracting the pending withdrawal.
     *      And the CLB tokens are minted or burned accordingly.
     *      The pending deposit and withdrawal amounts are passed to the vault for further processing.
     * @param self The BinLiquidity storage.
     * @param ctx The LpContext memory.
     * @param binValue The current value of the bin.
     * @param freeLiquidity The amount of free liquidity available in the bin.
     * @param clbTokenId The ID of the CLB token.
     */
    function settlePendingLiquidity(
        BinLiquidity storage self,
        LpContext memory ctx,
        uint256 binValue,
        uint256 freeLiquidity,
        uint256 clbTokenId,
        uint256 clbTokenTotalSupply
    ) internal {
        (uint256 pendingDeposit, uint256 mintingAmount) = _settlePending(
            self,
            ctx,
            binValue,
            clbTokenTotalSupply
        );
        (uint256 burningAmount, uint256 pendingWithdrawal) = _settleBurning(
            self,
            freeLiquidity + pendingDeposit,
            binValue,
            clbTokenTotalSupply
        );

        if (mintingAmount > burningAmount) {
            //slither-disable-next-line calls-loop
            ctx.clbToken.mint(ctx.market, clbTokenId, mintingAmount - burningAmount, bytes(""));
        } else if (mintingAmount < burningAmount) {
            //slither-disable-next-line calls-loop
            ctx.clbToken.burn(ctx.market, clbTokenId, burningAmount - mintingAmount);
        }

        if (pendingDeposit != 0 || pendingWithdrawal != 0) {
            //slither-disable-next-line calls-loop
            ctx.vault.onSettlePendingLiquidity(
                ctx.settlementToken,
                pendingDeposit,
                pendingWithdrawal
            );
        }
    }

    /**
     * @notice Adds liquidity to the BinLiquidity.
     * @dev Sets the pending liquidity with the specified amount and oracle version.
     *      Throws an error with the code `Errors.TOO_SMALL_AMOUNT` if the amount is too small.
     *      Throws an error with the code `Errors.INVALID_ORACLE_VERSION` if there is already pending liquidity with a different oracle version, it reverts with an error.
     * @param self The BinLiquidity storage.
     * @param amount The amount of tokens to add for liquidity.
     * @param oracleVersion The oracle version associated with the liquidity.
     */
    function onAddLiquidity(
        BinLiquidity storage self,
        uint256 amount,
        uint256 oracleVersion
    ) internal {
        require(amount > MIN_AMOUNT, Errors.TOO_SMALL_AMOUNT);

        uint256 pendingOracleVersion = self._pending.oracleVersion;
        require(
            pendingOracleVersion == 0 || pendingOracleVersion == oracleVersion,
            Errors.INVALID_ORACLE_VERSION
        );

        self._pending.oracleVersion = oracleVersion;
        self._pending.mintingTokenAmountRequested += amount;
    }

    /**
     * @notice Claims liquidity from the BinLiquidity by minting CLB tokens.
     * @dev Retrieves the minting details for the specified oracle version
     *      and calculates the CLB token amount to be claimed.
     *      Updates the claim minting details and returns the CLB token amount to be claimed.
     *      If there are no more tokens remaining for the claim, it is removed from the mapping.
     * @param self The BinLiquidity storage.
     * @param amount The amount of tokens to claim.
     * @param oracleVersion The oracle version associated with the claim.
     * @return clbTokenAmount The amount of CLB tokens to be claimed.
     */
    function onClaimLiquidity(
        BinLiquidity storage self,
        uint256 amount,
        uint256 oracleVersion
    ) internal returns (uint256 clbTokenAmount) {
        _ClaimMinting memory _cm = self._claimMintings[oracleVersion];
        clbTokenAmount = amount.mulDiv(_cm.clbTokenAmount, _cm.tokenAmountRequested);

        _cm.clbTokenAmount -= clbTokenAmount;
        _cm.tokenAmountRequested -= amount;
        if (_cm.tokenAmountRequested == 0) {
            delete self._claimMintings[oracleVersion];
        } else {
            self._claimMintings[oracleVersion] = _cm;
        }
    }

    /**
     * @notice Removes liquidity from the BinLiquidity by setting pending CLB token amount.
     * @dev Sets the pending liquidity with the specified CLB token amount and oracle version.
     *      Throws an error with the code `Errors.INVALID_ORACLE_VERSION` if there is already pending liquidity with a different oracle version, it reverts with an error.
     * @param self The BinLiquidity storage.
     * @param clbTokenAmount The amount of CLB tokens to remove liquidity.
     * @param oracleVersion The oracle version associated with the liquidity.
     */
    function onRemoveLiquidity(
        BinLiquidity storage self,
        uint256 clbTokenAmount,
        uint256 oracleVersion
    ) internal {
        uint256 pendingOracleVersion = self._pending.oracleVersion;
        require(
            pendingOracleVersion == 0 || pendingOracleVersion == oracleVersion,
            Errors.INVALID_ORACLE_VERSION
        );

        self._pending.oracleVersion = oracleVersion;
        self._pending.burningCLBTokenAmountRequested += clbTokenAmount;
    }

    /**
     * @notice Withdraws liquidity from the BinLiquidity by burning CLB tokens and withdrawing tokens.
     * @dev Retrieves the burning details for the specified oracle version
     *      and calculates the CLB token amount and token amount to burn and withdraw, respectively.
     *      Updates the claim burning details and returns the token amount to withdraw and the burned CLB token amount.
     *      If there are no more CLB tokens remaining for the claim, it is removed from the mapping.
     * @param self The BinLiquidity storage.
     * @param clbTokenAmount The amount of CLB tokens to withdraw.
     * @param oracleVersion The oracle version associated with the claim.
     * @return amount The amount of tokens to be withdrawn for the claim.
     * @return burnedCLBTokenAmount The amount of CLB tokens to be burned for the claim.
     */
    function onWithdrawLiquidity(
        BinLiquidity storage self,
        uint256 clbTokenAmount,
        uint256 oracleVersion
    ) internal returns (uint256 amount, uint256 burnedCLBTokenAmount) {
        _ClaimBurning memory _cb = self._claimBurnings[oracleVersion];
        amount = clbTokenAmount.mulDiv(_cb.tokenAmount, _cb.clbTokenAmountRequested);
        burnedCLBTokenAmount = clbTokenAmount.mulDiv(
            _cb.clbTokenAmount,
            _cb.clbTokenAmountRequested
        );

        _cb.clbTokenAmount -= burnedCLBTokenAmount;
        _cb.tokenAmount -= amount;
        _cb.clbTokenAmountRequested -= clbTokenAmount;
        if (_cb.clbTokenAmountRequested == 0) {
            delete self._claimBurnings[oracleVersion];
        } else {
            self._claimBurnings[oracleVersion] = _cb;
        }
    }

    /**
     * @notice Calculates the amount of CLB tokens to be minted
     *         for a given token amount, bin value, and CLB token total supply.
     * @dev If the CLB token total supply is zero, returns the token amount as is.
     *      Otherwise, calculates the minting amount
     *      based on the token amount, bin value, and CLB token total supply.
     * @param amount The amount of tokens to be minted.
     * @param binValue The current bin value.
     * @param clbTokenTotalSupply The total supply of CLB tokens.
     * @return The amount of CLB tokens to be minted.
     */
    function calculateCLBTokenMinting(
        uint256 amount,
        uint256 binValue,
        uint256 clbTokenTotalSupply
    ) internal pure returns (uint256) {
        return
            clbTokenTotalSupply == 0
                ? amount
                : amount.mulDiv(clbTokenTotalSupply, binValue < MIN_AMOUNT ? MIN_AMOUNT : binValue);
    }

    /**
     * @notice Calculates the value of CLB tokens
     *         for a given CLB token amount, bin value, and CLB token total supply.
     * @dev If the CLB token total supply is zero, returns zero.
     *      Otherwise, calculates the value based on the CLB token amount, bin value, and CLB token total supply.
     * @param clbTokenAmount The amount of CLB tokens.
     * @param binValue The current bin value.
     * @param clbTokenTotalSupply The total supply of CLB tokens.
     * @return The value of the CLB tokens.
     */
    function calculateCLBTokenValue(
        uint256 clbTokenAmount,
        uint256 binValue,
        uint256 clbTokenTotalSupply
    ) internal pure returns (uint256) {
        return clbTokenTotalSupply == 0 ? 0 : clbTokenAmount.mulDiv(binValue, clbTokenTotalSupply);
    }

    function needSettle(BinLiquidity storage self, LpContext memory ctx) internal returns (bool) {
        // trim all claim completed burning versions
        while (!self._burningVersions.empty()) {
            uint256 _ov = uint256(self._burningVersions.front());
            _ClaimBurning memory _cb = self._claimBurnings[_ov];
            if (_cb.clbTokenAmount >= _cb.clbTokenAmountRequested) {
                //slither-disable-next-line unused-return
                self._burningVersions.popFront();
                if (_cb.clbTokenAmountRequested == 0) {
                    delete self._claimBurnings[_ov];
                }
            } else {
                break;
            }
        }

        if (!ctx.isPastVersion(self._pending.oracleVersion)) return false;
        return
            self._pending.mintingTokenAmountRequested != 0 ||
            self._pending.burningCLBTokenAmountRequested != 0 ||
            self._burningVersions.length() != 0;
    }

    /**
     * @dev Settles the pending deposit and pending CLB token burning.
     * @param self The BinLiquidity storage.
     * @param ctx The LpContext.
     * @param binValue The current value of the bin.
     * @param totalSupply The total supply of CLB tokens.
     * @return pendingDeposit The amount of pending deposit to be settled.
     * @return mintingAmount The calculated minting amount of CLB tokens for the pending deposit.
     */
    function _settlePending(
        BinLiquidity storage self,
        LpContext memory ctx,
        uint256 binValue,
        uint256 totalSupply
    ) private returns (uint256 pendingDeposit, uint256 mintingAmount) {
        uint256 oracleVersion = self._pending.oracleVersion;
        if (!ctx.isPastVersion(oracleVersion)) return (0, 0);

        pendingDeposit = self._pending.mintingTokenAmountRequested;
        uint256 pendingCLBTokenAmount = self._pending.burningCLBTokenAmountRequested;

        if (pendingDeposit != 0) {
            mintingAmount = calculateCLBTokenMinting(pendingDeposit, binValue, totalSupply);

            self.total += pendingDeposit;
            self._claimMintings[oracleVersion] = _ClaimMinting({
                tokenAmountRequested: pendingDeposit,
                clbTokenAmount: mintingAmount
            });
        }

        if (pendingCLBTokenAmount != 0) {
            self._burningVersions.pushBack(bytes32(oracleVersion));
            self._claimBurnings[oracleVersion] = _ClaimBurning({
                clbTokenAmountRequested: pendingCLBTokenAmount,
                clbTokenAmount: 0,
                tokenAmount: 0
            });
        }

        delete self._pending;
    }

    /**
     * @dev Settles the pending CLB token burning and calculates the burning amount and pending withdrawal.
     * @param self The BinLiquidity storage.
     * @param freeLiquidity The amount of free liquidity available for burning.
     * @param binValue The current value of the bin.
     * @param totalSupply The total supply of CLB tokens.
     * @return burningAmount The calculated burning amount of CLB tokens.
     * @return pendingWithdrawal The calculated pending withdrawal amount.
     */
    function _settleBurning(
        BinLiquidity storage self,
        uint256 freeLiquidity,
        uint256 binValue,
        uint256 totalSupply
    ) private returns (uint256 burningAmount, uint256 pendingWithdrawal) {
        uint256 length = self._burningVersions.length();
        for (uint256 i; i < length && freeLiquidity != 0; i++) {
            uint256 _ov = uint256(self._burningVersions.at(i));
            _ClaimBurning storage _cb = self._claimBurnings[_ov];

            uint256 _pendingCLBTokenAmount = _cb.clbTokenAmountRequested - _cb.clbTokenAmount;
            if (_pendingCLBTokenAmount != 0) {
                uint256 _burningAmount;
                uint256 _pendingWithdrawal = calculateCLBTokenValue(
                    _pendingCLBTokenAmount,
                    binValue,
                    totalSupply
                );

                if (freeLiquidity >= _pendingWithdrawal) {
                    _burningAmount = _pendingCLBTokenAmount;
                } else {
                    _burningAmount = calculateCLBTokenMinting(freeLiquidity, binValue, totalSupply);
                    require(_burningAmount < _pendingCLBTokenAmount);
                    _pendingWithdrawal = freeLiquidity;
                }

                _cb.clbTokenAmount += _burningAmount;
                _cb.tokenAmount += _pendingWithdrawal;
                burningAmount += _burningAmount;
                pendingWithdrawal += _pendingWithdrawal;
                freeLiquidity -= _pendingWithdrawal;
            }
        }

        self.total -= pendingWithdrawal;
    }

    /**
     * @dev Retrieves the pending liquidity information.
     * @param self The reference to the BinLiquidity struct.
     * @return pendingLiquidity An instance of IMarketLiquidity.PendingLiquidity representing the pending liquidity information.
     */
    function pendingLiquidity(
        BinLiquidity storage self
    ) internal view returns (IMarketLiquidity.PendingLiquidity memory) {
        return self._pending;
    }

    /**
     * @dev Retrieves the claimable liquidity information for a specific oracle version.
     * @param self The reference to the BinLiquidity struct.
     * @param oracleVersion The oracle version for which to retrieve the claimable liquidity.
     * @return claimableLiquidity An instance of IMarketLiquidity.ClaimableLiquidity representing the claimable liquidity information.
     */
    function claimableLiquidity(
        BinLiquidity storage self,
        uint256 oracleVersion
    ) internal view returns (IMarketLiquidity.ClaimableLiquidity memory) {
        _ClaimMinting memory _cm = self._claimMintings[oracleVersion];
        _ClaimBurning memory _cb = self._claimBurnings[oracleVersion];

        return
            IMarketLiquidity.ClaimableLiquidity({
                mintingTokenAmountRequested: _cm.tokenAmountRequested,
                mintingCLBTokenAmount: _cm.clbTokenAmount,
                burningCLBTokenAmountRequested: _cb.clbTokenAmountRequested,
                burningCLBTokenAmount: _cb.clbTokenAmount,
                burningTokenAmount: _cb.tokenAmount
            });
    }
}
