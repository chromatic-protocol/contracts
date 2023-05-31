// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {ILendingPool} from "@usum/core/interfaces/vault/ILendingPool.sol";
import {IVault} from "@usum/core/interfaces/vault/IVault.sol";

interface IUSUMVault is IVault, ILendingPool {
    event MarketEarningAccumulated(address indexed market, uint256 earning);

    event MakerEarningDistributed(
        address indexed token,
        uint256 indexed earning,
        uint256 indexed usedKeeperFee
    );

    event MarketEarningDistributed(
        address indexed market,
        uint256 indexed earning,
        uint256 indexed usedKeeperFee,
        uint256 marketBalance
    );

    function createMakerEarningDistributionTask(address token) external;

    function cancelMakerEarningDistributionTask(address token) external;

    function createMarketEarningDistributionTask(address market) external;

    function cancelMarketEarningDistributionTask(address market) external;
}
