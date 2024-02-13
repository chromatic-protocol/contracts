// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {IOracleProviderPullBased} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProviderPullBased.sol";
import {IMarketSettlement} from "@chromatic-protocol/contracts/core/interfaces/IMarketSettlement.sol";
import {IMate2Automation1_1} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2Automation1_1.sol";
import {IMate2AutomationRegistry1_1, ExtraModule} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2AutomationRegistry1_1.sol";
import {IUpkeepTreasury} from "@chromatic-protocol/contracts/core/automation/mate2/IUpkeepTreasury.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {FEE_RATES_LENGTH} from "@chromatic-protocol/contracts/core/libraries/Constants.sol";
import {PendingPosition, ClosingPosition, PendingLiquidity} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import {OracleProviderLib} from "@chromatic-protocol/contracts/oracle/libraries/OracleProviderLib.sol";

contract Mate2MarketSettlement is IMarketSettlement, IMate2Automation1_1 {
    uint32 public constant DEFAULT_UPKEEP_GAS_LIMIT = 2e7;

    IChromaticMarketFactory public immutable factory;
    IMate2AutomationRegistry1_1 public immutable automate;

    uint32 public upkeepGasLimit;
    mapping(address => uint256) public marketSettlementUpkeepIds; // market => upkeep id

    event UpkeepGasLimitUpdated(uint32 gasLimitOld, uint32 gasLimitNew);

    /**
     * @dev Throws an error indicating that the caller is not the DAO.
     */
    error OnlyAccessableByDao();

    /**
     * @dev Throws an error indicating that the caller is neither the chromatic factory contract nor the DAO.
     */
    error OnlyAccessableByFactoryOrDao();

    /**
     * @dev Throws an error indicating that a market settlement task already exists.
     */
    error ExistMarketSettlementTask();

    /**
     * @dev Throws an error indicating that the keeper fee is insufficient
     */
    error InsufficientKeeperFee();

    /**
     * @dev Throws an error indicating that the payment of the keeper fee has failed.
     */
    error PayKeeperFeeFailed();

    /**
     * @dev Throws an error indicating that the transfer of Ether has failed.
     */
    error EthTransferFailed();

    /**
     * @dev Modifier to restrict access to only the DAO.
     *      Throws an `OnlyAccessableByDao` error if the caller is not the DAO.
     */
    modifier onlyDao() {
        if (msg.sender != factory.dao()) revert OnlyAccessableByDao();
        _;
    }

    /**
     * @dev Modifier to restrict access to only the factory or the DAO.
     *      Throws an `OnlyAccessableByFactoryOrDao` error if the caller is neither the chromatic factory contract nor the DAO.
     */
    modifier onlyFactoryOrDao() {
        if (msg.sender != address(factory) && msg.sender != factory.dao())
            revert OnlyAccessableByFactoryOrDao();
        _;
    }

    constructor(IChromaticMarketFactory _factory, address _automate) {
        factory = _factory;
        automate = IMate2AutomationRegistry1_1(_automate);
        upkeepGasLimit = DEFAULT_UPKEEP_GAS_LIMIT;
    }

    /**
     * @inheritdoc IMate2Automation1_1
     */
    function checkUpkeep(
        bytes calldata checkData,
        bytes calldata extraData
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        address market = abi.decode(checkData, (address));
        return resolveSettlement(market, extraData);
    }

    /**
     * @inheritdoc IMate2Automation1_1
     */
    function performUpkeep(bytes calldata performData) external {
        _payKeeperFee();
        (address market, bytes memory extraData) = abi.decode(performData, (address, bytes));
        updatePrice(market, extraData);
        settle(market);
    }

    /**
     * @inheritdoc IMarketSettlement
     * @dev This function can only be called by the Chromatic factory contract or the DAO.
     *      Throws an `ExistMarketSettlementTask` error if a market earning distribution task already exists for the market.
     */
    function createSettlementTask(address market) external override onlyFactoryOrDao {
        if (marketSettlementUpkeepIds[market] != 0) revert ExistMarketSettlementTask();

        IOracleProvider oracleProvider = IChromaticMarket(market).oracleProvider();

        if (!OracleProviderLib.isPullBased(oracleProvider)) {
            return;
        }

        IOracleProviderPullBased pullBasedOracle = IOracleProviderPullBased(
            address(oracleProvider)
        );

        automate.registerUpkeep(
            address(this),
            upkeepGasLimit,
            address(this), // address admin,
            false, // bool useTreasury,
            false, // bool singleExec,
            abi.encode(market),
            pullBasedOracle.extraModule(),
            pullBasedOracle.extraParam()
        );
    }

    /**
     * @inheritdoc IMarketSettlement
     */
    function cancelSettlementTask(address market) external override onlyFactoryOrDao {
        uint256 upkeepId = marketSettlementUpkeepIds[market];
        if (upkeepId != 0) {
            delete marketSettlementUpkeepIds[market];
            try automate.cancelUpkeep(upkeepId) {} catch Error(string memory reason) {
                //slither-disable-next-line reentrancy-events
                emit catchErr("cancelUpkeep", reason);
            }
        }
    }

    /**
     * @inheritdoc IMarketSettlement
     */
    function resolveSettlement(
        address market,
        bytes calldata extraData
    ) public view override returns (bool canExec, bytes memory execPayload) {
        int16[] memory feeRates = _feeRates();
        IOracleProvider.OracleVersion memory currentOracleVersion = IChromaticMarket(market)
            .oracleProvider()
            .currentVersion();

        PendingPosition[] memory pendingPositions = IChromaticMarket(market).pendingPositionBatch(
            feeRates
        );
        for (uint256 i; i < pendingPositions.length; ) {
            PendingPosition memory _pos = pendingPositions[i];
            if (_pos.openVersion != 0 && _pos.openVersion < currentOracleVersion.version) {
                return (true, abi.encode(market, extraData));
            }

            unchecked {
                ++i;
            }
        }

        ClosingPosition[] memory closingPositions = IChromaticMarket(market).closingPositionBatch(
            feeRates
        );
        for (uint256 i; i < closingPositions.length; ) {
            ClosingPosition memory _pos = closingPositions[i];
            if (_pos.closeVersion != 0 && _pos.closeVersion < currentOracleVersion.version) {
                return (true, abi.encode(market, extraData));
            }

            unchecked {
                ++i;
            }
        }

        PendingLiquidity[] memory pendingLiquidities = IChromaticMarket(market)
            .pendingLiquidityBatch(feeRates);
        for (uint256 i; i < pendingLiquidities.length; ) {
            PendingLiquidity memory _liq = pendingLiquidities[i];
            if (_liq.oracleVersion != 0 && _liq.oracleVersion < currentOracleVersion.version) {
                return (true, abi.encode(market, extraData));
            }

            unchecked {
                ++i;
            }
        }

        return (false, "");
    }

    /**
     * @inheritdoc IMarketSettlement
     */
    function settle(address market) public override {
        IChromaticMarket(market).settleAll();
    }

    function _feeRates() private pure returns (int16[] memory rates) {
        rates = new int16[](FEE_RATES_LENGTH * 2);
        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates = CLBTokenLib.tradingFeeRates();
        for (uint i; i < FEE_RATES_LENGTH; ) {
            rates[i] = int16(_tradingFeeRates[i]);
            rates[i + FEE_RATES_LENGTH] = -int16(_tradingFeeRates[i]);

            unchecked {
                ++i;
            }
        }
    }

    // for management
    function balanceOfUpkeepTreasury() external view returns (uint256) {
        IUpkeepTreasury treasury = IUpkeepTreasury(automate.getUpkeepTreasury());
        return treasury.userBalance(address(this));
    }

    function withdrawUpkeepTreasuryFunds(
        address payable _receiver,
        uint256 _amount
    ) external onlyDao {
        IUpkeepTreasury treasury = IUpkeepTreasury(automate.getUpkeepTreasury());
        treasury.withdrawFunds(_receiver, _amount);
    }

    function cancelUpkeep(uint256 upkeepId) external onlyDao {
        automate.cancelUpkeep(upkeepId);
    }

    function updateUpkeepGasLimit(uint32 gasLimit) external onlyDao {
        uint32 gasLimitOld = upkeepGasLimit;
        upkeepGasLimit = gasLimit;
        emit UpkeepGasLimitUpdated(gasLimitOld, gasLimit);
    }

    /**
     * @inheritdoc IMarketSettlement
     */
    function updatePrice(address market, bytes memory extraData) public override {
        IOracleProvider oracleProvider = IChromaticMarket(market).oracleProvider();

        if (OracleProviderLib.isPullBased(oracleProvider)) {
            IOracleProviderPullBased pullBasedOracle = IOracleProviderPullBased(
                address(oracleProvider)
            );
            uint256 fee = pullBasedOracle.getUpdateFee(extraData);
            pullBasedOracle.updatePrice{value: fee}(extraData);
        }
    }

    function _payKeeperFee() private {
        uint256 keeperFee = automate.getPerformUpkeepFee();
        if (address(this).balance < keeperFee) revert InsufficientKeeperFee();
        (bool success, ) = address(automate).call{value: keeperFee}("");
        if (!success) revert PayKeeperFeeFailed();
    }

    /**
     * @dev Fallback function to receive ETH payments.
     */
    receive() external payable {}

    /**
     * @dev Fallback function to receive ETH payments.
     */
    fallback() external payable {}

    /**
     * @inheritdoc IMarketSettlement
     */
    function withdraw(address recipient, uint256 amount) external override onlyDao {
        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert EthTransferFailed();
    }
}
