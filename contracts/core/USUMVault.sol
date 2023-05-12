// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUSUMMarketFactory} from "@usum/core/interfaces/IUSUMMarketFactory.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";
import {IUSUMVault} from "@usum/core/interfaces/IUSUMVault.sol";
import {IKeeperFeePayer} from "@usum/core/interfaces/IKeeperFeePayer.sol";
import {IUSUMFlashLoanCallback} from "@usum/core/interfaces/callback/IUSUMFlashLoanCallback.sol";
import {AutomateReady} from "@usum/core/base/gelato/AutomateReady.sol";
import {IAutomate, Module, ModuleData} from "@usum/core/base/gelato/Types.sol";
import {Constants} from "@usum/core/libraries/Constants.sol";

contract USUMVault is IUSUMVault, ReentrancyGuard, AutomateReady {
    using Math for uint256;

    uint256 private constant DISTRIBUTION_INTERVAL = 1 hours;

    IUSUMMarketFactory factory;
    IKeeperFeePayer keeperFeePayer;

    mapping(address => uint256) public makerBalances; // settlement token => balance
    mapping(address => uint256) public takerBalances; // settlement token => balance
    mapping(address => uint256) public makerMarketBalances; // market => balance
    mapping(address => uint256) public takerMarketBalances; // market => balance
    mapping(address => uint256) public pendingMakerEarnings; // settlement token => earning
    mapping(address => uint256) public pendingMarketEarnings; // market => earning

    mapping(address => bytes32) public makerEarningDistributionTaskIds; // settlement token => task id
    mapping(address => bytes32) public marketEarningDistributionTaskIds; // market => task id

    error OnlyAccessableByFactory();
    error OnlyAccessableByMarket();
    error NotEnoughBalance();
    error NotEnoughFeePaid();
    error ExistMarketEarningDistributionTask();
    error ExistSlotEarningDistributionTask();

    modifier onlyFactory() {
        if (msg.sender != address(factory)) revert OnlyAccessableByFactory();
        _;
    }

    modifier onlyMarket() {
        if (!factory.isRegisteredMarket(msg.sender))
            revert OnlyAccessableByMarket();
        _;
    }

    constructor(
        IUSUMMarketFactory _factory,
        address _automate,
        address opsProxyFactory
    ) AutomateReady(_automate, address(this), opsProxyFactory) {
        factory = _factory;
        keeperFeePayer = IKeeperFeePayer(factory.keeperFeePayer());
    }

    // implement IVault

    function onOpenPosition(
        uint256 positionId,
        uint256 takerMargin,
        uint256 tradingFee,
        uint256 protocolFee
    ) external override onlyMarket {
        IUSUMMarket market = IUSUMMarket(msg.sender);
        address settlementToken = address(market.settlementToken());

        takerBalances[settlementToken] += takerMargin;
        takerMarketBalances[address(market)] += takerMargin;

        makerBalances[settlementToken] += tradingFee;
        makerMarketBalances[address(market)] += tradingFee;

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

        SafeERC20.safeTransfer(
            IERC20(settlementToken),
            recipient,
            settlmentAmount
        );

        takerBalances[settlementToken] -= takerMargin;
        takerMarketBalances[address(market)] -= takerMargin;

        if (settlmentAmount > takerMargin) {
            // maker loss
            uint256 makerLoss = settlmentAmount - takerMargin;

            makerBalances[settlementToken] -= makerLoss;
            makerMarketBalances[address(market)] -= makerLoss;
        } else {
            // maker profit
            uint256 makerProfit = takerMargin - settlmentAmount;

            makerBalances[settlementToken] += makerProfit;
            makerMarketBalances[address(market)] += makerProfit;
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

        makerBalances[settlementToken] += amount;
        makerMarketBalances[address(market)] += amount;

        emit OnAddLiquidity(address(market), amount);
    }

    function onRemoveLiquidity(
        address recipient,
        uint256 amount
    ) external override onlyMarket {
        IUSUMMarket market = IUSUMMarket(msg.sender);
        address settlementToken = address(market.settlementToken());

        SafeERC20.safeTransfer(IERC20(settlementToken), recipient, amount);

        makerBalances[settlementToken] -= amount;
        makerMarketBalances[address(market)] -= amount;

        emit OnRemoveLiquidity(address(market), amount, recipient);
    }

    function transferKeeperFee(
        address keeper,
        uint256 fee,
        uint256 margin
    ) external override onlyMarket returns (uint256 usedFee) {
        return _transferKeeperFee(keeper, fee, margin);
    }

    function _transferKeeperFee(
        address keeper,
        uint256 fee,
        uint256 margin
    ) internal returns (uint256 usedFee) {
        IUSUMMarket market = IUSUMMarket(msg.sender);
        address settlementToken = address(market.settlementToken());

        // swap to native token
        SafeERC20.safeTransfer(
            IERC20(settlementToken),
            address(keeperFeePayer),
            margin
        );
        usedFee = keeperFeePayer.payKeeperFee(
            address(settlementToken),
            fee,
            keeper
        );

        takerBalances[settlementToken] -= usedFee;
        takerMarketBalances[address(market)] -= usedFee;

        emit TransferKeeperFee(address(market), fee, usedFee);
    }

    function transferProtocolFee(
        address market,
        address settlementToken,
        uint256 positionId,
        uint256 amount
    ) internal {
        if (amount > 0) {
            SafeERC20.safeTransfer(
                IERC20(settlementToken),
                factory.treasury(),
                amount
            );
            emit TransferProtocolFee(market, positionId, amount);
        }
    }

    // implement ILendingPool

    function flashLoan(
        address token,
        uint256 amount,
        address recipient,
        bytes calldata data
    ) external nonReentrant {
        uint256 balance = IERC20(token).balanceOf(address(this));

        if (amount > balance) revert NotEnoughBalance();

        uint256 fee = amount.mulDiv(
            factory.getFlashLoanFeeRate(token),
            Constants.BPS,
            Math.Rounding.Up
        );

        SafeERC20.safeTransfer(IERC20(token), recipient, amount);

        IUSUMFlashLoanCallback(msg.sender).flashLoanCallback(fee, data);

        uint256 balanceAfter = IERC20(token).balanceOf(address(this));

        if (balanceAfter < balance + fee) revert NotEnoughFeePaid();

        uint256 paid = balanceAfter - balance;

        uint256 takerBalance = takerBalances[token];
        uint256 makerBalance = makerBalances[token];
        uint256 paidToTakerPool = paid.mulDiv(
            takerBalance,
            takerBalance + makerBalance
        );
        uint256 paidToMakerPool = paid - paidToTakerPool;

        if (paidToTakerPool > 0) {
            SafeERC20.safeTransfer(
                IERC20(token),
                factory.treasury(),
                paidToTakerPool
            );
        }
        pendingMakerEarnings[token] += paidToMakerPool;

        emit FlashLoan(
            msg.sender,
            recipient,
            amount,
            paid,
            paidToTakerPool,
            paidToMakerPool
        );
    }

    function getPendingSlotShare(
        address market,
        uint256 slotBalance
    ) external view returns (uint256) {
        address token = address(IUSUMMarket(market).settlementToken());
        uint256 makerBalance = makerBalances[token];
        uint256 marketBalance = makerMarketBalances[market];

        return
            pendingMakerEarnings[token].mulDiv(
                slotBalance,
                makerBalance,
                Math.Rounding.Up
            ) +
            pendingMarketEarnings[market].mulDiv(
                slotBalance,
                marketBalance,
                Math.Rounding.Up
            );
    }

    // gelato automate - distribute maker earning to each markets

    function resolveMakerEarningDistribution(
        address token
    ) external view returns (bool canExec, bytes memory execPayload) {
        if (_makerEarningDistributable(token)) {
            return (true, abi.encodeCall(this.distributeMakerEarning, token));
        }

        return (false, "");
    }

    function distributeMakerEarning(
        address token
    ) external onlyDedicatedMsgSender {
        (uint256 fee, ) = _getFeeDetails();
        _distributeMakerEarning(token, fee);
    }

    function createMakerEarningDistributionTask(
        address token
    ) external override onlyFactory {
        if (makerEarningDistributionTaskIds[token] != bytes32(0))
            revert ExistMarketEarningDistributionTask();

        ModuleData memory moduleData = ModuleData({
            modules: new Module[](3),
            args: new bytes[](3)
        });

        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.TIME;
        moduleData.modules[2] = Module.PROXY;
        moduleData.args[0] = _resolverModuleArg(
            abi.encodeCall(this.resolveMakerEarningDistribution, token)
        );
        moduleData.args[1] = _timeModuleArg(
            block.timestamp,
            DISTRIBUTION_INTERVAL
        );
        moduleData.args[2] = _proxyModuleArg();

        makerEarningDistributionTaskIds[token] = automate.createTask(
            address(this),
            abi.encode(this.distributeMakerEarning.selector),
            moduleData,
            ETH
        );
    }

    function cancelMakerEarningDistributionTask(
        address token
    ) external override onlyFactory {
        bytes32 taskId = makerEarningDistributionTaskIds[token];
        if (taskId != bytes32(0)) {
            automate.cancelTask(taskId);
            delete makerEarningDistributionTaskIds[token];
        }
    }

    function _distributeMakerEarning(
        address token,
        uint256 keeperFee
    ) internal {
        if (!_makerEarningDistributable(token)) return;

        address[] memory markets = factory.getMarketsBySettlmentToken(token);

        uint256 earning = pendingMakerEarnings[token];
        delete pendingMakerEarnings[token];

        uint256 usedKeeperFee = _transferKeeperFee(
            automate.gelato(),
            keeperFee,
            earning
        );

        uint256 remainBalance = makerBalances[token];
        uint256 remainEarning = earning - usedKeeperFee;
        for (uint256 i = 0; i < markets.length; i++) {
            address market = markets[i];
            uint256 marketBalance = makerMarketBalances[market];
            uint256 marketEarning = remainEarning.mulDiv(
                marketBalance,
                remainBalance
            );

            pendingMarketEarnings[market] += marketEarning;

            remainBalance -= marketBalance;
            remainEarning -= marketEarning;

            emit MarketEarningAccumulated(market, marketEarning);
        }

        emit MakerEarningDistributed(token, earning, usedKeeperFee);
    }

    function _makerEarningDistributable(
        address token
    ) private view returns (bool) {
        return
            pendingMakerEarnings[token] >=
            factory.getEarningDistributionThreshold(token);
    }

    // gelato automate - distribute market earning to each slots

    function resolveMarketEarningDistribution(
        address market
    ) external view returns (bool canExec, bytes memory execPayload) {
        address token = address(IUSUMMarket(market).settlementToken());
        if (_marketEarningDistributable(market, token)) {
            return (true, abi.encodeCall(this.distributeMarketEarning, market));
        }

        return (false, "");
    }

    function distributeMarketEarning(
        address market
    ) external onlyDedicatedMsgSender {
        address token = address(IUSUMMarket(market).settlementToken());
        if (!_marketEarningDistributable(market, token)) return;

        uint256 earning = pendingMarketEarnings[market];
        delete pendingMarketEarnings[market];

        IUSUMMarket(market).distributeEarningToSlots(
            earning,
            makerMarketBalances[market]
        );

        makerMarketBalances[market] += earning;
        makerBalances[token] += earning;
    }

    function createMarketEarningDistributionTask(
        address market
    ) external override onlyFactory {
        if (marketEarningDistributionTaskIds[market] != bytes32(0))
            revert ExistMarketEarningDistributionTask();

        ModuleData memory moduleData = ModuleData({
            modules: new Module[](3),
            args: new bytes[](3)
        });

        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.TIME;
        moduleData.modules[2] = Module.PROXY;
        moduleData.args[0] = _resolverModuleArg(
            abi.encodeCall(this.resolveMarketEarningDistribution, market)
        );
        moduleData.args[1] = _timeModuleArg(
            block.timestamp,
            DISTRIBUTION_INTERVAL
        );
        moduleData.args[2] = _proxyModuleArg();

        marketEarningDistributionTaskIds[market] = automate.createTask(
            address(this),
            abi.encode(this.distributeMarketEarning.selector),
            moduleData,
            ETH
        );
    }

    function cancelMarketEarningDistributionTask(
        address market
    ) external override onlyFactory {
        bytes32 taskId = marketEarningDistributionTaskIds[market];
        if (taskId != bytes32(0)) {
            automate.cancelTask(taskId);
            delete marketEarningDistributionTaskIds[market];
        }
    }

    function _distributeMarketEarning(
        address market,
        uint256 keeperFee
    ) internal {
        address token = address(IUSUMMarket(market).settlementToken());
        if (!_marketEarningDistributable(market, token)) return;

        uint256 balance = makerMarketBalances[market];
        uint256 earning = pendingMarketEarnings[market];
        delete pendingMarketEarnings[market];

        uint256 usedKeeperFee = _transferKeeperFee(
            automate.gelato(),
            keeperFee,
            earning
        );

        uint256 remainEarning = earning - usedKeeperFee;
        IUSUMMarket(market).distributeEarningToSlots(remainEarning, balance);

        makerMarketBalances[market] += remainEarning;
        makerBalances[token] += remainEarning;

        emit MarketEarningDistributed(market, earning, usedKeeperFee, balance);
    }

    function _marketEarningDistributable(
        address market,
        address token
    ) private view returns (bool) {
        return
            pendingMarketEarnings[market] >=
            factory.getEarningDistributionThreshold(token);
    }

    function _resolverModuleArg(
        bytes memory _resolverData
    ) internal view returns (bytes memory) {
        return abi.encode(address(this), _resolverData);
    }

    function _timeModuleArg(
        uint256 _startTime,
        uint256 _interval
    ) internal pure returns (bytes memory) {
        return abi.encode(uint128(_startTime), uint128(_interval));
    }

    function _proxyModuleArg() internal pure returns (bytes memory) {
        return bytes("");
    }
}
