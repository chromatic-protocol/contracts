// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IUSUMMarketFactory} from "@usum/core/interfaces/IUSUMMarketFactory.sol";

abstract contract MarketFactoryBase is IUSUMMarketFactory {
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
}
