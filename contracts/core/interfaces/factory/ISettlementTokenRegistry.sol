// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {InterestRate} from "@chromatic/core/libraries/InterestRate.sol";

interface ISettlementTokenRegistry {
    event SettlementTokenRegistered(
        address indexed token,
        uint256 indexed minimumTakerMargin,
        uint256 indexed interestRate,
        uint256 flashLoanFeeRate,
        uint256 earningDistributionThreshold,
        uint24 uniswapFeeTier
    );

    event SetMinimumTakerMargin(address indexed token, uint256 indexed minimumTakerMargin);

    event SetFlashLoanFeeRate(address indexed token, uint256 indexed flashLoanFeeRate);

    event SetEarningDistributionThreshold(
        address indexed token,
        uint256 indexed earningDistributionThreshold
    );

    event SetUniswapFeeTier(address indexed token, uint24 indexed uniswapFeeTier);

    event InterestRateRecordAppended(
        address indexed token,
        uint256 indexed annualRateBPS,
        uint256 indexed beginTimestamp
    );

    event LastInterestRateRecordRemoved(
        address indexed token,
        uint256 indexed annualRateBPS,
        uint256 indexed beginTimestamp
    );

    function registerSettlementToken(
        address token,
        uint256 minimumTakerMargin,
        uint256 interestRate,
        uint256 flashLoanFeeRate,
        uint256 earningDistributionThreshold,
        uint24 uniswapFeeTier
    ) external;

    function registeredSettlementTokens() external view returns (address[] memory);

    function isRegisteredSettlementToken(address token) external view returns (bool);

    function getMinimumTakerMargin(address token) external view returns (uint256);

    function setMinimumTakerMargin(address token, uint256 minimumTakerMargin) external;

    function getFlashLoanFeeRate(address token) external view returns (uint256);

    function setFlashLoanFeeRate(address token, uint256 flashLoanFeeRate) external;

    function getEarningDistributionThreshold(address token) external view returns (uint256);

    function setEarningDistributionThreshold(
        address token,
        uint256 earningDistributionThreshold
    ) external;

    function getUniswapFeeTier(address token) external view returns (uint24);

    function setUniswapFeeTier(address token, uint24 uniswapFeeTier) external;

    function appendInterestRateRecord(
        address token,
        uint256 annualRateBPS,
        uint256 beginTimestamp
    ) external;

    function removeLastInterestRateRecord(address token) external;

    function currentInterestRate(address token) external view returns (uint256);

    function getInterestRateRecords(
        address token
    ) external view returns (InterestRate.Record[] memory);
}
