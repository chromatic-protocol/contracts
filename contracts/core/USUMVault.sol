// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {SafeERC20} from "@usum/core/libraries/SafeERC20.sol";
import {IUSUMMarketFactory} from "@usum/core/interfaces/IUSUMMarketFactory.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";
import {IUSUMVault} from "@usum/core/interfaces/IUSUMVault.sol";
import {IKeeperFeePayer} from "@usum/core/interfaces/IKeeperFeePayer.sol";

contract USUMVault is IUSUMVault {
    IUSUMMarketFactory factory;
    IKeeperFeePayer keeperFeePayer;

    mapping(address => uint256) makerBalance;
    mapping(address => uint256) takerBalance;
    mapping(address => uint256) makerBalancePerMarket;
    mapping(address => uint256) takerBalancePerMarket;

    error OnlyAccessableByMarket();

    modifier onlyMarket() {
        if (!factory.isRegisteredMarket(msg.sender))
            revert OnlyAccessableByMarket();
        _;
    }

    constructor(IUSUMMarketFactory _factory) {
        factory = _factory;
        keeperFeePayer = IKeeperFeePayer(factory.keeperFeePayer());
    }

    function onOpenPosition(
        uint256 positionId,
        uint256 takerMargin,
        uint256 tradingFee,
        uint256 protocolFee
    ) external override onlyMarket {
        IUSUMMarket market = IUSUMMarket(msg.sender);
        address settlementToken = address(market.settlementToken());

        takerBalance[settlementToken] += takerMargin;
        takerBalancePerMarket[address(market)] += takerMargin;

        makerBalance[settlementToken] += tradingFee;
        makerBalancePerMarket[address(market)] += tradingFee;

        transferProtocolFee(
            address(market),
            settlementToken,
            positionId,
            protocolFee
        );

        emit OnOpenPosition(
            address(market),
            positionId,
            takerMargin,
            tradingFee,
            protocolFee
        );
    }

    function onClosePosition(
        uint256 positionId,
        address recipient,
        uint256 takerMargin,
        uint256 settlmentAmount
    ) external override onlyMarket {
        IUSUMMarket market = IUSUMMarket(msg.sender);
        address settlementToken = address(market.settlementToken());

        SafeERC20.safeTransfer(settlementToken, recipient, settlmentAmount);

        takerBalance[settlementToken] -= takerMargin;
        takerBalancePerMarket[address(market)] -= takerMargin;

        if (settlmentAmount > takerMargin) {
            // maker loss
            uint256 makerLoss = settlmentAmount - takerMargin;

            makerBalance[settlementToken] -= makerLoss;
            makerBalancePerMarket[address(market)] -= makerLoss;
        } else {
            // maker profit
            uint256 makerProfit = takerMargin - settlmentAmount;

            makerBalance[settlementToken] += makerProfit;
            makerBalancePerMarket[address(market)] += makerProfit;
        }

        emit OnClosePosition(
            address(market),
            positionId,
            recipient,
            takerMargin,
            settlmentAmount
        );
    }

    function onAddLiquidity(uint256 amount) external override onlyMarket {
        IUSUMMarket market = IUSUMMarket(msg.sender);
        address settlementToken = address(market.settlementToken());

        makerBalance[settlementToken] += amount;
        makerBalancePerMarket[address(market)] += amount;

        emit OnAddLiquidity(address(market), amount);
    }

    function onRemoveLiquidity(
        address recipient,
        uint256 amount
    ) external override onlyMarket {
        IUSUMMarket market = IUSUMMarket(msg.sender);
        address settlementToken = address(market.settlementToken());

        SafeERC20.safeTransfer(settlementToken, recipient, amount);

        makerBalance[settlementToken] -= amount;
        makerBalancePerMarket[address(market)] -= amount;

        emit OnRemoveLiquidity(address(market), amount, recipient);
    }

    function transferKeeperFee(
        address keeper,
        uint256 fee,
        uint256 margin
    ) external override onlyMarket returns (uint256 usedFee) {
        IUSUMMarket market = IUSUMMarket(msg.sender);
        address settlementToken = address(market.settlementToken());

        // swap to native token
        SafeERC20.safeTransfer(
            settlementToken,
            address(keeperFeePayer),
            margin
        );
        usedFee = keeperFeePayer.payKeeperFee(
            address(settlementToken),
            fee,
            keeper
        );

        takerBalance[settlementToken] -= usedFee;
        takerBalancePerMarket[address(market)] -= usedFee;

        emit TransferKeeperFee(address(market), fee, usedFee);
    }

    function transferProtocolFee(
        address market,
        address settlementToken,
        uint256 positionId,
        uint256 amount
    ) internal {
        if (amount > 0) {
            SafeERC20.safeTransfer(settlementToken, factory.dao(), amount);
            emit TransferProtocolFee(market, positionId, amount);
        }
    }
}
