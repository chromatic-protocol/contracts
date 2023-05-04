// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

uint256 constant BPS = 10000;

library InterestRate {
    using Math for uint256;

    struct Record {
        uint256 annualRateBPS;
        uint256 beginTimestamp;
    }

    uint256 private constant MAX_RATE_BPS = BPS; // max interest rate is 100%
    uint256 private constant YEAR = 365 * 24 * 3600;

    modifier initialized(Record[] storage self) {
        require(self.length > 0, "IRNI"); // Interest Rate Not Initialized
        _;
    }

    function initialize(
        Record[] storage self,
        uint256 initialInterestRate
    ) internal {
        self.push(
            Record({annualRateBPS: initialInterestRate, beginTimestamp: 0})
        );
    }

    function appendRecord(
        Record[] storage self,
        uint256 annualRateBPS,
        uint256 beginTimestamp
    ) internal initialized(self) {
        require(annualRateBPS <= MAX_RATE_BPS, "IROF"); // Interest Rate OvferFlow
        require(beginTimestamp > block.timestamp, "IRPT"); // Interest Rate Past Timestamp

        Record memory lastRecord = self[self.length - 1];
        require(beginTimestamp > lastRecord.beginTimestamp, "IRNA"); // Interest Rate Not Appendable

        self.push(
            Record({
                annualRateBPS: annualRateBPS,
                beginTimestamp: beginTimestamp
            })
        );
    }

    function removeLastRecord(
        Record[] storage self
    ) internal initialized(self) returns (bool removed, Record memory record) {
        if (self.length <= 1) {
            // empty
            return (false, Record(0, 0));
        }

        Record memory lastRecord = self[self.length - 1];
        require(block.timestamp >= lastRecord.beginTimestamp, "IRAA"); // Interest Rate Already Applied

        self.pop();

        return (true, lastRecord);
    }

    function findRecordAt(
        Record[] storage self,
        uint256 timestamp
    )
        internal
        view
        initialized(self)
        returns (Record memory interestRate, uint256 index)
    {
        for (index = self.length - 1; index >= 0; index--) {
            interestRate = self[index];

            if (interestRate.beginTimestamp <= timestamp) {
                return (interestRate, index);
            }
        }

        return (self[0], 0); // empty result (this line is not reachable)
    }

    function calculateInterest(
        Record[] storage self,
        uint256 amount,
        uint256 from, // timestamp (inclusive)
        uint256 to // timestamp (exclusive)
    ) internal view returns (uint256) {
        return calculateInterest(self, amount, from, to, Math.Rounding.Down);
    }

    function calculateInterest(
        Record[] storage self,
        uint256 amount,
        uint256 from, // timestamp (inclusive)
        uint256 to, // timestamp (exclusive)
        Math.Rounding rounding // use Rouding.Up to deduct accumulated accrued interest
    ) internal view initialized(self) returns (uint256) {
        if (from >= to) {
            return 0;
        }

        uint256 interest = 0;

        uint256 endTimestamp = type(uint256).max;
        for (uint256 idx = self.length - 1; idx > 0; idx--) {
            Record memory record = self[idx];
            if (endTimestamp <= from) {
                break;
            }

            interest += _interest(
                amount,
                record.annualRateBPS,
                Math.min(to, endTimestamp) -
                    Math.max(from, record.beginTimestamp),
                rounding
            );
            endTimestamp = record.beginTimestamp;
        }

        return interest;
    }

    function _interest(
        uint256 amount,
        uint256 rateBPS, // annual rate
        uint256 period, // in seconds
        Math.Rounding rounding
    ) private pure returns (uint256) {
        return amount.mulDiv(rateBPS * period, BPS * YEAR, rounding);
    }
}
