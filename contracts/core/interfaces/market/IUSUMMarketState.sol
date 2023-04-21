// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {IUSUMFactory} from "@usum/core/interfaces/IUSUMFactory.sol";

interface IUSUMMarketState {
    function factory() external view returns (IUSUMFactory);

    function settlementToken() external view returns (IERC20);

    function oracleProvider() external view returns (IOracleProvider);
}
