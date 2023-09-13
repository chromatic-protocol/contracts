// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {IChromaticLP} from "@chromatic-protocol/contracts/lp/interfaces/IChromaticLP.sol";

struct ValueInfo {
    uint256 total;
    uint256 holding;
    uint256 pending;
    uint256 holdingClb;
    uint256 pendingClb;
}

interface IChromaticLPLens {
    function utilization() external view returns (uint16);

    function totalValue() external view returns (uint256);

    function valueInfo() external view returns (ValueInfo memory info);

    function holdingValue() external view returns (uint256);

    function pendingValue() external view returns (uint256);

    function holdingClbValue() external view returns (uint256);

    function pendingClbValue() external view returns (uint256);

    function totalClbValue() external view returns (uint256 value);

    function feeRates() external view returns (int16[] memory feeRates);

    function clbTokenIds() external view returns (uint256[] memory tokenIds);

    function clbTokenBalances() external view returns (uint256[] memory balances);
}
