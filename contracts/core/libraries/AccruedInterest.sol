// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IInterestCalculator} from "@usum/core/interfaces/IInterestCalculator.sol";

struct AccruedInterest {
    uint256 accumulatedAt;
    uint256 accumulatedAmount;
}

using AccruedInterestLib for AccruedInterest global;

library AccruedInterestLib {
    function accumulate(
        AccruedInterest storage self,
        IInterestCalculator calculator,
        uint256 tokenAmount,
        uint256 until
    ) internal {
        uint256 accumulatedAt = self.accumulatedAt;
        if (until <= accumulatedAt) return;

        if (tokenAmount > 0) {
            self.accumulatedAmount += calculator.calculateInterest(
                tokenAmount,
                accumulatedAt,
                until
            );
        }
        self.accumulatedAt = until;
    }

    function deduct(AccruedInterest storage self, uint256 amount) internal {
        uint256 accumulatedAmount = self.accumulatedAmount;
        if (amount >= accumulatedAmount) {
            self.accumulatedAmount = 0;
        } else {
            self.accumulatedAmount = accumulatedAmount - amount;
        }
    }

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

        return
            accumulatedAmount +
            calculator.calculateInterest(tokenAmount, accumulatedAt, until);
    }
}
