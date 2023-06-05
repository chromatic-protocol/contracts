// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IOracleProvider} from "@chromatic/core/interfaces/IOracleProvider.sol";
import {IChromaticMarketFactory} from "@chromatic/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticLiquidator} from "@chromatic/core/interfaces/IChromaticLiquidator.sol";
import {IChromaticVault} from "@chromatic/core/interfaces/IChromaticVault.sol";
import {ICLBToken} from "@chromatic/core/interfaces/ICLBToken.sol";
import {IKeeperFeePayer} from "@chromatic/core/interfaces/IKeeperFeePayer.sol";

interface IMarketState {
    function factory() external view returns (IChromaticMarketFactory);

    function settlementToken() external view returns (IERC20Metadata);

    function oracleProvider() external view returns (IOracleProvider);

    function clbToken() external view returns (ICLBToken);

    function liquidator() external view returns (IChromaticLiquidator);

    function vault() external view returns (IChromaticVault);

    function keeperFeePayer() external view returns (IKeeperFeePayer);
}
