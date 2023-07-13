// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {IKeeperFeePayer} from "@chromatic-protocol/contracts/core/interfaces/IKeeperFeePayer.sol";
import {ILendingPool} from "@chromatic-protocol/contracts/core/interfaces/vault/ILendingPool.sol";
import {IVault} from "@chromatic-protocol/contracts/core/interfaces/vault/IVault.sol";
import {IChromaticFlashLoanCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticFlashLoanCallback.sol";
import {AutomateReady} from "@chromatic-protocol/contracts/core/base/gelato/AutomateReady.sol";
import {IAutomate, Module, ModuleData} from "@chromatic-protocol/contracts/core/base/gelato/Types.sol";
import {BPS} from "@chromatic-protocol/contracts/core/libraries/Constants.sol";

/**
 * @title ChromaticVault
 * @dev A contract that implements the ChromaticVault interface
 *      and provides functionality for managing positions, liquidity, and fees in Chromatic markets.
 */
contract ChromaticVault is IChromaticVault, ReentrancyGuard, AutomateReady {
    using Math for uint256;

    uint256 private constant DISTRIBUTION_INTERVAL = 1 hours;

    IChromaticMarketFactory factory;
    IKeeperFeePayer keeperFeePayer;

    mapping(address => uint256) public makerBalances; // settlement token => balance
    mapping(address => uint256) public takerBalances; // settlement token => balance
    mapping(address => uint256) public makerMarketBalances; // market => balance
    mapping(address => uint256) public takerMarketBalances; // market => balance
    mapping(address => uint256) public pendingMakerEarnings; // settlement token => earning
    mapping(address => uint256) public pendingMarketEarnings; // market => earning
    mapping(address => uint256) public pendingDeposits; // settlement token => deposit
    mapping(address => uint256) public pendingWithdrawals; // settlement token => deposit

    mapping(address => bytes32) public makerEarningDistributionTaskIds; // settlement token => task id
    mapping(address => bytes32) public marketEarningDistributionTaskIds; // market => task id

    /**
     * @dev Throws an error indicating that the caller is nether the chormatic factory contract nor the DAO.
     */
    error OnlyAccessableByFactoryOrDao();

    /**
     * @dev Throws an error indicating that the caller is not a registered market.
     */
    error OnlyAccessableByMarket();

    /**
     * @dev Throws an error indicating that the flash loan amount exceeds the available balance in the vault.
     */
    error NotEnoughBalance();

    /**
     * @dev Throws an error indicating that the recipient has not paid the sufficient flash loan fee.
     */
    error NotEnoughFeePaid();

    /**
     * @dev Throws an error indicating that a maker earning distribution task already exists.
     */
    error ExistMakerEarningDistributionTask();

    /**
     * @dev Throws an error indicating that a market earning distribution task already exists.
     */
    error ExistMarketEarningDistributionTask();

    /**
     * @dev Modifier to restrict access to only the factory or the DAO.
     *      Throws an `OnlyAccessableByFactoryOrDao` error if the caller is nether the chormatic factory contract nor the DAO.
     */
    modifier onlyFactoryOrDao() {
        if (msg.sender != address(factory) && msg.sender != factory.dao())
            revert OnlyAccessableByFactoryOrDao();
        _;
    }

    /**
     * @dev Modifier to restrict access to only the Market contract.
     *      Throws an `OnlyAccessableByMarket` error if the caller is not a registered market.
     */
    modifier onlyMarket() {
        if (!factory.isRegisteredMarket(msg.sender)) revert OnlyAccessableByMarket();
        _;
    }

    /**
     * @dev Constructs a new ChromaticVault instance.
     * @param _factory The address of the Chromatic Market Factory contract.
     * @param _automate The address of the Gelato Automate contract.
     * @param opsProxyFactory The address of the OpsProxyFactory contract.
     */
    constructor(
        IChromaticMarketFactory _factory,
        address _automate,
        address opsProxyFactory
    ) AutomateReady(_automate, address(this), opsProxyFactory) {
        factory = _factory;
        keeperFeePayer = IKeeperFeePayer(factory.keeperFeePayer());
    }

    // implement IVault

    /**
     * @inheritdoc IVault
     * @dev This function can only be called by a market contract.
     */
    function onOpenPosition(
        address settlementToken,
        uint256 positionId,
        uint256 takerMargin,
        uint256 tradingFee,
        uint256 protocolFee
    ) external override onlyMarket {
        address market = msg.sender;

        takerBalances[settlementToken] += takerMargin;
        takerMarketBalances[market] += takerMargin;

        makerBalances[settlementToken] += tradingFee;
        makerMarketBalances[market] += tradingFee;

        transferProtocolFee(market, settlementToken, positionId, protocolFee);

        emit OnOpenPosition(market, positionId, takerMargin, tradingFee, protocolFee);
    }

    /**
     * @inheritdoc IVault
     * @dev This function can only be called by a market contract.
     */
    function onClaimPosition(
        address settlementToken,
        uint256 positionId,
        address recipient,
        uint256 takerMargin,
        uint256 settlementAmount
    ) external override onlyMarket {
        address market = msg.sender;

        SafeERC20.safeTransfer(IERC20(settlementToken), recipient, settlementAmount);

        takerBalances[settlementToken] -= takerMargin;
        takerMarketBalances[market] -= takerMargin;

        if (settlementAmount > takerMargin) {
            // maker loss
            uint256 makerLoss = settlementAmount - takerMargin;

            makerBalances[settlementToken] -= makerLoss;
            makerMarketBalances[market] -= makerLoss;
        } else {
            // maker profit
            uint256 makerProfit = takerMargin - settlementAmount;

            makerBalances[settlementToken] += makerProfit;
            makerMarketBalances[market] += makerProfit;
        }

        emit OnClaimPosition(market, positionId, recipient, takerMargin, settlementAmount);
    }

    /**
     * @inheritdoc IVault
     * @dev This function can only be called by a market contract.
     */
    function onAddLiquidity(address settlementToken, uint256 amount) external override onlyMarket {
        address market = msg.sender;

        pendingDeposits[settlementToken] += amount;

        emit OnAddLiquidity(market, amount);
    }

    /**
     * @inheritdoc IVault
     * @dev This function can only be called by a market contract.
     */
    function onSettlePendingLiquidity(
        address settlementToken,
        uint256 pendingDeposit,
        uint256 pendingWithdrawal
    ) external override onlyMarket {
        address market = msg.sender;

        pendingDeposits[settlementToken] -= pendingDeposit;
        pendingWithdrawals[settlementToken] += pendingWithdrawal;
        makerBalances[settlementToken] =
            makerBalances[settlementToken] +
            pendingDeposit -
            pendingWithdrawal;
        makerMarketBalances[market] =
            makerMarketBalances[market] +
            pendingDeposit -
            pendingWithdrawal;

        emit OnSettlePendingLiquidity(market, pendingDeposit, pendingWithdrawal);
    }

    /**
     * @inheritdoc IVault
     * @dev This function can only be called by a market contract.
     */
    function onWithdrawLiquidity(
        address settlementToken,
        address recipient,
        uint256 amount
    ) external override onlyMarket {
        address market = msg.sender;

        SafeERC20.safeTransfer(IERC20(settlementToken), recipient, amount);

        pendingWithdrawals[settlementToken] -= amount;

        emit OnWithdrawLiquidity(market, amount, recipient);
    }

    /**
     * @inheritdoc IVault
     * @dev This function can only be called by a market contract.
     */
    function transferKeeperFee(
        address settlementToken,
        address keeper,
        uint256 fee,
        uint256 margin
    ) external override onlyMarket returns (uint256 usedFee) {
        if (fee == 0) return 0;

        address market = msg.sender;

        usedFee = _transferKeeperFee(settlementToken, keeper, fee, margin);

        takerBalances[settlementToken] -= usedFee;
        takerMarketBalances[market] -= usedFee;

        emit TransferKeeperFee(market, fee, usedFee);
    }

    /**
     * @notice Internal function to transfer the keeper fee.
     * @param token The address of the settlement token.
     * @param keeper The address of the keeper to receive the fee.
     * @param fee The amount of the fee to transfer as native token.
     * @param margin The margin amount used for the fee payment.
     * @return usedFee The actual settlement token amount of fee used for the transfer.
     */
    function _transferKeeperFee(
        address token,
        address keeper,
        uint256 fee,
        uint256 margin
    ) internal returns (uint256 usedFee) {
        if (fee == 0) return 0;

        // swap to native token
        SafeERC20.safeTransfer(IERC20(token), address(keeperFeePayer), margin);

        return keeperFeePayer.payKeeperFee(token, fee, keeper);
    }

    /**
     * @notice Transfers the protocol fee to the DAO treasury address.
     * @param market The address of the market contract.
     * @param settlementToken The address of the settlement token.
     * @param positionId The ID of the position.
     * @param amount The amount of the protocol fee to transfer.
     */
    function transferProtocolFee(
        address market,
        address settlementToken,
        uint256 positionId,
        uint256 amount
    ) internal {
        if (amount != 0) {
            SafeERC20.safeTransfer(IERC20(settlementToken), factory.treasury(), amount);
            emit TransferProtocolFee(market, positionId, amount);
        }
    }

    // implement ILendingPool

    /**
     * @inheritdoc ILendingPool
     * @dev
     *  Throws a `NotEnoughBalance` error if the loan amount exceeds the available balance.
     *  Throws a `NotEnoughFeePaid` error if the fee has not been paid by the recipient.
     *
     * Requirements:
     * - The loan amount must not exceed the available balance after considering pending deposits and withdrawals.
     * - The fee for the flash loan must be paid by the recipient.
     * - The total amount paid must be distributed between the taker pool and maker pool according to their balances.
     * - The amount paid to the taker pool must be transferred to the DAO treasury address.
     * - The amount paid to the maker pool must be added to the pending maker earnings.
     *
     * Emits a `FlashLoan` event with details of the flash loan execution.
     */
    function flashLoan(
        address token,
        uint256 amount,
        address recipient,
        bytes calldata data
    ) external nonReentrant {
        uint256 balance = IERC20(token).balanceOf(address(this));

        // Ensure that the loan amount does not exceed the available balance
        // after considering pending deposits and withdrawals
        if (amount > balance - pendingDeposits[token] - pendingWithdrawals[token])
            revert NotEnoughBalance();

        // Calculate the fee for the flash loan based on the loan amount and the flash loan fee rate of the token
        uint256 fee = amount.mulDiv(factory.getFlashLoanFeeRate(token), BPS, Math.Rounding.Up);

        SafeERC20.safeTransfer(IERC20(token), recipient, amount);

        // Invoke the flash loan callback function on the sender contract to process the loan
        IChromaticFlashLoanCallback(msg.sender).flashLoanCallback(fee, data);

        uint256 balanceAfter = IERC20(token).balanceOf(address(this));

        // Ensure that the fee has been paid by the recipient
        if (balanceAfter < balance + fee) revert NotEnoughFeePaid();

        uint256 paid = balanceAfter - balance;

        // Calculate the amounts to be distributed to the taker pool and maker pool
        uint256 takerBalance = takerBalances[token];
        uint256 makerBalance = makerBalances[token];
        uint256 paidToTakerPool = paid.mulDiv(takerBalance, takerBalance + makerBalance);
        uint256 paidToMakerPool = paid - paidToTakerPool;

        // Transfer the amount paid to the taker pool to the DAO treasury address
        if (paidToTakerPool != 0) {
            SafeERC20.safeTransfer(IERC20(token), factory.treasury(), paidToTakerPool);
        }
        // Add the amount paid to the maker pool to the pending maker earnings
        pendingMakerEarnings[token] += paidToMakerPool;

        emit FlashLoan(msg.sender, recipient, amount, paid, paidToTakerPool, paidToMakerPool);
    }

    /**
     * @inheritdoc ILendingPool
     * @dev The pending share of earnings is calculated based on the bin balance, maker balances, and market balances.
     */
    function getPendingBinShare(
        address market,
        address settlementToken,
        uint256 binBalance
    ) external view returns (uint256) {
        uint256 makerBalance = makerBalances[settlementToken];
        uint256 marketBalance = makerMarketBalances[market];

        return
            (
                // Calculate the pending share of earnings for the bin based on the maker balances and bin balance
                makerBalance == 0
                    ? 0
                    : pendingMakerEarnings[settlementToken].mulDiv(
                        binBalance,
                        makerBalance,
                        Math.Rounding.Up
                    )
            ) +
            (
                // Calculate the pending share of earnings for the bin based on the market balances and bin balance
                marketBalance == 0
                    ? 0
                    : pendingMarketEarnings[market].mulDiv(
                        binBalance,
                        marketBalance,
                        Math.Rounding.Up
                    )
            );
    }

    // gelato automate - distribute maker earning to each markets

    /**
     * @notice Resolves the maker earning distribution for a specific token.
     * @param token The address of the settlement token.
     * @return canExec True if the distribution can be executed, otherwise False.
     * @return execPayload The payload for executing the distribution.
     */
    function resolveMakerEarningDistribution(
        address token
    ) external view returns (bool canExec, bytes memory execPayload) {
        if (_makerEarningDistributable(token)) {
            return (true, abi.encodeCall(this.distributeMakerEarning, token));
        }

        return (false, "");
    }

    /**
     * @notice Distributes the maker earning for a token to the each markets.
     * @param token The address of the settlement token.
     */
    function distributeMakerEarning(address token) external {
        (uint256 fee, ) = _getFeeDetails();
        _distributeMakerEarning(token, fee);
    }

    /**
     * @inheritdoc IChromaticVault
     * @dev This function can only be called by the Chromatic factory contract or the DAO.
     *      Throws an `ExistMakerEarningDistributionTask` error if a maker earning distribution task already exists for the token.
     */
    function createMakerEarningDistributionTask(
        address token
    ) external virtual override onlyFactoryOrDao {
        if (makerEarningDistributionTaskIds[token] != bytes32(0))
            revert ExistMakerEarningDistributionTask();

        ModuleData memory moduleData = ModuleData({modules: new Module[](3), args: new bytes[](3)});

        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.TIME;
        moduleData.modules[2] = Module.PROXY;
        moduleData.args[0] = _resolverModuleArg(
            abi.encodeCall(this.resolveMakerEarningDistribution, token)
        );
        moduleData.args[1] = _timeModuleArg(block.timestamp, DISTRIBUTION_INTERVAL);
        moduleData.args[2] = _proxyModuleArg();

        makerEarningDistributionTaskIds[token] = automate.createTask(
            address(this),
            abi.encode(this.distributeMakerEarning.selector),
            moduleData,
            ETH
        );
    }

    /**
     * @inheritdoc IChromaticVault
     */
    function cancelMakerEarningDistributionTask(
        address token
    ) external virtual override onlyFactoryOrDao {
        bytes32 taskId = makerEarningDistributionTaskIds[token];
        if (taskId != bytes32(0)) {
            automate.cancelTask(taskId);
            delete makerEarningDistributionTaskIds[token];
        }
    }

    /**
     * @dev Internal function to distribute the maker earning for a token to the each markets.
     * @param token The address of the settlement token.
     * @param fee The keeper fee amount.
     */
    function _distributeMakerEarning(address token, uint256 fee) internal {
        if (!_makerEarningDistributable(token)) return;

        address[] memory markets = factory.getMarketsBySettlmentToken(token);

        uint256 earning = pendingMakerEarnings[token];
        delete pendingMakerEarnings[token];

        uint256 usedFee = fee != 0 ? _transferKeeperFee(token, automate.gelato(), fee, earning) : 0;
        emit TransferKeeperFee(fee, usedFee);

        uint256 remainBalance = makerBalances[token];
        uint256 remainEarning = earning - usedFee;
        for (uint256 i; i < markets.length; ) {
            address market = markets[i];
            uint256 marketBalance = makerMarketBalances[market];
            uint256 marketEarning = remainEarning.mulDiv(marketBalance, remainBalance);

            pendingMarketEarnings[market] += marketEarning;

            remainBalance -= marketBalance;
            remainEarning -= marketEarning;

            emit MarketEarningAccumulated(market, marketEarning);

            unchecked {
                i++;
            }
        }

        emit MakerEarningDistributed(token, earning, usedFee);
    }

    /**
     * @dev Private function to check if the maker earning is distributable for a token.
     * @param token The address of the settlement token.
     * @return True if the maker earning is distributable, False otherwise.
     */
    function _makerEarningDistributable(address token) private view returns (bool) {
        return pendingMakerEarnings[token] >= factory.getEarningDistributionThreshold(token);
    }

    // gelato automate - distribute market earning to each bins

    /**
     * @notice Resolves the market earning distribution for a market.
     * @param market The address of the market.
     * @return canExec True if the distribution can be executed.
     * @return execPayload The payload for executing the distribution.
     */
    function resolveMarketEarningDistribution(
        address market
    ) external view returns (bool canExec, bytes memory execPayload) {
        address token = address(IChromaticMarket(market).settlementToken());
        if (_marketEarningDistributable(market, token)) {
            return (true, abi.encodeCall(this.distributeMarketEarning, market));
        }

        return (false, "");
    }

    /**
     * @notice Distributes the market earning for a market to the each bins.
     * @param market The address of the market.
     */
    function distributeMarketEarning(address market) external {
        (uint256 fee, ) = _getFeeDetails();
        _distributeMarketEarning(market, fee);
    }

    /**
     * @inheritdoc IChromaticVault
     * @dev This function can only be called by the Chromatic factory contract or the DAO.
     *      Throws an `ExistMarketEarningDistributionTask` error if a market earning distribution task already exists for the market.
     */
    function createMarketEarningDistributionTask(
        address market
    ) external virtual override onlyFactoryOrDao {
        if (marketEarningDistributionTaskIds[market] != bytes32(0))
            revert ExistMarketEarningDistributionTask();

        ModuleData memory moduleData = ModuleData({modules: new Module[](3), args: new bytes[](3)});

        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.TIME;
        moduleData.modules[2] = Module.PROXY;
        moduleData.args[0] = _resolverModuleArg(
            abi.encodeCall(this.resolveMarketEarningDistribution, market)
        );
        moduleData.args[1] = _timeModuleArg(block.timestamp, DISTRIBUTION_INTERVAL);
        moduleData.args[2] = _proxyModuleArg();

        marketEarningDistributionTaskIds[market] = automate.createTask(
            address(this),
            abi.encode(this.distributeMarketEarning.selector),
            moduleData,
            ETH
        );
    }

    /**
     * @inheritdoc IChromaticVault
     */
    function cancelMarketEarningDistributionTask(
        address market
    ) external virtual override onlyFactoryOrDao {
        bytes32 taskId = marketEarningDistributionTaskIds[market];
        if (taskId != bytes32(0)) {
            automate.cancelTask(taskId);
            delete marketEarningDistributionTaskIds[market];
        }
    }

    /**
     * @dev Internal function to distribute the market earning for a market to the each bins.
     * @param market The address of the market.
     * @param fee The fee amount.
     */
    function _distributeMarketEarning(address market, uint256 fee) internal {
        address token = address(IChromaticMarket(market).settlementToken());
        if (!_marketEarningDistributable(market, token)) return;

        uint256 earning = pendingMarketEarnings[market];
        delete pendingMarketEarnings[market];

        uint256 usedFee = fee != 0 ? _transferKeeperFee(token, automate.gelato(), fee, earning) : 0;
        emit TransferKeeperFee(market, fee, usedFee);

        uint256 remainEarning = earning - usedFee;

        uint256 balance = makerMarketBalances[market];
        makerMarketBalances[market] += remainEarning;
        makerBalances[token] += remainEarning;

        IChromaticMarket(market).distributeEarningToBins(remainEarning, balance);

        emit MarketEarningDistributed(market, earning, usedFee, balance);
    }

    /**
     * @dev Private function to check if the market earning is distributable for a market.
     * @param market The address of the market.
     * @param token The address of the settlement token.
     * @return True if the market earning is distributable, False otherwise.
     */
    function _marketEarningDistributable(
        address market,
        address token
    ) private view returns (bool) {
        return pendingMarketEarnings[market] >= factory.getEarningDistributionThreshold(token);
    }

    function _resolverModuleArg(bytes memory _resolverData) internal view returns (bytes memory) {
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
