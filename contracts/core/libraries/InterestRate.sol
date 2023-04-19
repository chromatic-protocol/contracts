// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/math/Math.sol";

uint256 constant BPS = 10000;

struct Record {
    uint256 annualRateBPS;
    uint256 beginTimestamp;
}

library InterestRateLib {
    using Math for uint256;

    uint256 private constant MAX_RATE_BPS = BPS; // max interest rate is 100%
    uint256 private constant YEAR = 365 * 24 * 3600;

    modifier initialized(Record[] storage self) {
        require(self.length > 0, "not initalized");
        _;
    }

    function initialize(Record[] storage self) internal {
        self.push(Record({annualRateBPS: 0, beginTimestamp: 0}));
    }

    function appendRecord(
        Record[] storage self,
        uint256 annualRateBPS,
        uint256 beginTimestamp
    ) internal initialized(self) {
        require(annualRateBPS <= MAX_RATE_BPS, "annual rate bps overflow");
        require(beginTimestamp > block.timestamp, "past timestamp");

        Record memory lastRecord = self[self.length - 1];
        require(beginTimestamp > lastRecord.beginTimestamp, "not appendable");

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
        require(
            block.timestamp >= lastRecord.beginTimestamp,
            "already applied interest rate"
        );

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
                    Math.max(from, record.beginTimestamp)
            );
            endTimestamp = record.beginTimestamp;
        }

        return interest;
    }

    function _interest(
        uint256 amount,
        uint256 rateBPS, // annual rate
        uint256 period // in seconds
    ) private pure returns (uint256) {
        return amount.mulDiv(rateBPS * period, BPS * YEAR);
    }
}