// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {IInterestCalculator} from "@usum/core/interfaces/IInterestCalculator.sol";
import {IUSUMFactory} from "@usum/core/interfaces/IUSUMFactory.sol";
import {IUSUMMarket, IUSUMLiquidity} from "@usum/core/interfaces/IUSUMMarket.sol";
import {IMarketDeployer} from "@usum/core/interfaces/IMarketDeployer.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlotPosition} from "@usum/core/libraries/LpSlotPosition.sol";
import {LpSlotSet} from "@usum/core/libraries/LpSlotSet.sol";

abstract contract MarketBase is IUSUMMarket {
    IUSUMFactory public immutable override factory;
    IOracleProvider public immutable override oracleProvider;
    IERC20Metadata public immutable override settlementToken;

    LpSlotSet internal lpSlotSet;

    // liquidity
    // uint256 internal lpReserveRatio;

    modifier onlyDao() {
        // TODO
        // require(msg.sender == factory.dao());
        _;
    }

    constructor() {
        factory = IUSUMFactory(msg.sender);

        (address _oracleProvider, address _settlementToken, ) = factory
            .parameters();

        oracleProvider = IOracleProvider(_oracleProvider);
        settlementToken = IERC20Metadata(_settlementToken);

        // lpTokenName = string(
        //     abi.encodePacked(
        //         "zsToken (",
        //         underlyingAsset.symbol(),
        //         "/",
        //         settlementToken.symbol(),
        //         ")"
        //     )
        // );
    }

    function newLpContext() internal view returns (LpContext memory) {
        return
            LpContext({
                oracleProvider: oracleProvider,
                interestCalculator: IInterestCalculator(address(factory)),
                tokenPrecision: 10 ** settlementToken.decimals(),
                _pricePrecision: 0,
                _currentVersionCache: OracleVersion(0, 0, 0)
            });
    }
}
