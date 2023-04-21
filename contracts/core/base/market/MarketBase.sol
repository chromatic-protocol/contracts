// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {IUSUMFactory} from "@usum/core/interfaces/IUSUMFactory.sol";
import {IUSUMMarket, IUSUMLiquidity} from "@usum/core/interfaces/IUSUMMarket.sol";
import {IMarketDeployer} from "@usum/core/interfaces/IMarketDeployer.sol";
import {LpSlotPosition} from "@usum/core/libraries/LpSlotPosition.sol";

import {LpSlotSet} from "@usum/core/libraries/LpSlotSetMock.sol";

abstract contract MarketBase is IUSUMMarket {
    IUSUMFactory public immutable override factory;
    IOracleProvider public immutable override oracleProvider;
    IERC20 public immutable override settlementToken;
    LpSlotSet public lpSlotSet; // TODO add interface

    // liquidity
    // uint256 internal lpReserveRatio;

    modifier onlyDao() {
        // TODO
        // require(msg.sender == factory.dao());
        _;
    }

    constructor() {
        factory = IUSUMFactory(msg.sender);

        (
            address _oracleProvider,
            address _settlementToken,
            string memory lpTokenUri
        ) = factory.parameters();

        oracleProvider = IOracleProvider(_oracleProvider);
        settlementToken = IERC20(_settlementToken);
        IUSUMLiquidity(address(this)).setURI(lpTokenUri);

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
}
