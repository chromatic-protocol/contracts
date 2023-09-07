// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {IChromaticLP} from "@chromatic-protocol/contracts/lp/interfaces/IChromaticLP.sol";

interface IChromaticLPLens {
    function value(address lp) external view returns (uint256);

    function values(
        address lp
    ) external returns (uint256 _totalValue, uint256 _clbValue, uint256 _holdingValue);

    function clbValue(address lp) external view returns (uint256);

    function holdingValue(address lp) external view returns (uint256);

    function utitlity(address lp) external view returns (uint256);
}
