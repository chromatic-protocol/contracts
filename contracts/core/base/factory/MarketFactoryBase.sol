// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

// import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
// import {InterestRateLib} from "@usum/core/libraries/InterestRate.sol";
// import {ISettlementTokenRegistry} from "@usum/core/interfaces/ISettlementTokenRegistry.sol";
import {IUSUMMarketFactory} from "@usum/core/interfaces/IUSUMMarketFactory.sol";

// import {InterestRateLib, Record} from "@usum/core/libraries/InterestRate.sol";
// import {Registry} from "@usum/core/libraries/SettlementToken.sol";

abstract contract MarketFactoryBase is IUSUMMarketFactory {
    address public override dao;

    modifier onlyDao() {
        require(msg.sender == dao);
        _;
    }

    constructor() {
        dao = msg.sender;
    }

    function updateDao(address _dao) external onlyDao {
        dao = _dao;
    }
}
