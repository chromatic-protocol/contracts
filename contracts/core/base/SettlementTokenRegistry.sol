// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {InterestRateLib} from "@usum/core/libraries/InterestRate.sol";
import {ISettlementTokenRegistry} from "@usum/core/interfaces/ISettlementTokenRegistry.sol";
import {InterestRateLib, Record} from "@usum/core/libraries/InterestRate.sol";
import {Registry} from "@usum/core/libraries/SettlementToken.sol";

abstract contract SettlementTokenRegistry is ISettlementTokenRegistry {
    using InterestRateLib for Record[];

    event RegisterSettlementToken(address indexed token);
    event AppendInterestRateRecord(
        address indexed token,
        uint256 annualRateBPS,
        uint256 beginTimestamp
    );
    event RemoveLastInterestRateRecord(
        address indexed token,
        uint256 annualRateBPS,
        uint256 beginTimestamp
    );

    error AlreadyRegisteredToken();
    error UnregisteredToken();

    address public override dao;

    modifier onlyDao() {
        require(msg.sender == dao, "only DAO can access");
        _;
    }

    constructor() {
        dao = msg.sender;
    }

    function updateDao(address _dao) external onlyDao {
        dao = _dao;
    }

    Registry private registry;

    modifier registeredOnly(address token) {
        if (!registry.contains(token)) {
            revert UnregisteredToken();
        }
        _;
    }

    function registerSettlementToken(address token) external override onlyDao {
        if (!registry.register(token)) {
            revert AlreadyRegisteredToken();
        }

        emit RegisterSettlementToken(token);
    }

    function isRegistered(address token) external view override returns (bool) {
        return registry.contains(token);
    }

    function appendInterestRateRecord(
        address token,
        uint256 annualRateBPS,
        uint256 beginTimestamp
    ) external override onlyDao registeredOnly(token) {
        getInterestRateRecords(token).appendRecord(
            annualRateBPS,
            beginTimestamp
        );

        emit AppendInterestRateRecord(token, annualRateBPS, beginTimestamp);
    }

    function removeLastInterestRateRecord(
        address token
    ) external override onlyDao registeredOnly(token) {
        (bool removed, Record memory record) = getInterestRateRecords(token)
            .removeLastRecord();

        if (removed) {
            emit RemoveLastInterestRateRecord(
                token,
                record.annualRateBPS,
                record.beginTimestamp
            );
        }
    }

    function currentInterestRate(
        address token
    )
        external
        view
        override
        registeredOnly(token)
        returns (uint256 annualRateBPS)
    {
        (Record memory record, ) = getInterestRateRecords(token).findRecordAt(
            block.timestamp
        );
        return record.annualRateBPS;
    }

    function calculateInterest(
        address token,
        uint256 amount,
        uint256 from, // timestamp (inclusive)
        uint256 to // timestamp (exclusive)
    ) public view override registeredOnly(token) returns (uint256) {
        return calculateInterest(token, amount, from, to, Math.Rounding.Down);
    }

    function calculateInterest(
        address token,
        uint256 amount,
        uint256 from, // timestamp (inclusive)
        uint256 to, // timestamp (exclusive)
        Math.Rounding rounding
    ) public view override registeredOnly(token) returns (uint256) {
        return
            getInterestRateRecords(token).calculateInterest(
                amount,
                from,
                to,
                rounding
            );
    }

    function getInterestRateRecords(
        address token
    ) internal view returns (Record[] storage) {
        return registry.getInterestRateRecords(token);
    }
}
