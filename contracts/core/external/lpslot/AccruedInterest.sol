// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IInterestCalculator} from "@usum/core/interfaces/market/IInterestCalculator.sol";

/// @dev AccruedInterest type
struct AccruedInterest {
    /// @dev The timestamp at which the interest was last accumulated.
    uint256 accumulatedAt;
    /// @dev The total amount of interest accumulated.
    uint256 accumulatedAmount;
}

/**
 * @title AccruedInterestLib
 * @notice Tracks the accumulated interest for a given token amount and period of time
 */
library AccruedInterestLib {
    /**
     * @notice Accumulates interest for a given period of time.
     * @param self The AccruedInterest storage.
     * @param calculator The interest calculator.
     * @param tokenAmount The amount of tokens.
     * @param until The timestamp until which interest should be accumulated.
     */
    function accumulate(
        AccruedInterest storage self,
        IInterestCalculator calculator,
        uint256 tokenAmount,
        uint256 until
    ) internal {
        uint256 accumulatedAt = self.accumulatedAt;
        // check if the interest is already accumulated for the given period of time.
        if (until <= accumulatedAt) return;

        if (tokenAmount > 0) {
            // calculate the interest for the given period of time and accumulate it
            self.accumulatedAmount += calculator.calculateInterest(
                tokenAmount,
                accumulatedAt,
                until
            );
        }
        // update the timestamp at which the interest was last accumulated.
        self.accumulatedAt = until;
    }

    /**
     * @notice Deducts interest from the accumulated interest.
     * @param self The AccruedInterest storage.
     * @param amount The amount of interest to deduct.
     */
    function deduct(AccruedInterest storage self, uint256 amount) internal {
        uint256 accumulatedAmount = self.accumulatedAmount;
        // check if the amount is greater than the accumulated interest.
        if (amount >= accumulatedAmount) {
            self.accumulatedAmount = 0;
        } else {
            self.accumulatedAmount = accumulatedAmount - amount;
        }
    }

    /**
     * @notice Calculates the total interest accumulated for a given period of time.
     * @param self The AccruedInterest storage.
     * @param calculator The interest calculator.
     * @param tokenAmount The amount of tokens.
     * @param until The timestamp until which interest should be calculated.
     * @return The total interest accumulated.
     */
    function calculateInterest(
        AccruedInterest storage self,
        IInterestCalculator calculator,
        uint256 tokenAmount,
        uint256 until
    ) internal view returns (uint256) {
        if (tokenAmount == 0) return 0;

        uint256 accumulatedAt = self.accumulatedAt;
        uint256 accumulatedAmount = self.accumulatedAmount;
        if (until <= accumulatedAt) return accumulatedAmount;

        return accumulatedAmount + calculator.calculateInterest(tokenAmount, accumulatedAt, until);
    }
}
