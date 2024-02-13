// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {IMarketSettlement} from "@chromatic-protocol/contracts/core/interfaces/IMarketSettlement.sol";
import {IMate2Automation} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2Automation.sol";
import {IMate2AutomationRegistry} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2AutomationRegistry.sol";
import {IUpkeepTreasury} from "@chromatic-protocol/contracts/core/automation/mate2/IUpkeepTreasury.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {FEE_RATES_LENGTH} from "@chromatic-protocol/contracts/core/libraries/Constants.sol";
import {PendingPosition, ClosingPosition, PendingLiquidity} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";

contract Mate2MarketSettlement is IMarketSettlement, IMate2Automation {
    IChromaticMarketFactory public immutable factory;
    IMate2AutomationRegistry public immutable automate;

    mapping(address => uint256) public marketSettlementUpkeepIds; // market => upkeep id

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
        automate = IMate2AutomationRegistry(_automate);
    }

    /**
     * @inheritdoc IMate2Automation
     */
    function checkUpkeep(
        bytes calldata checkData
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        address market = abi.decode(checkData, (address));
        return resolveSettlement(market);
    }

    /**
     * @inheritdoc IMate2Automation
     */
    function performUpkeep(bytes calldata performData) external {
        address market = abi.decode(performData, (address));
        settle(market);
    }

    /**
     * @inheritdoc IMarketSettlement
     * @dev This function can only be called by the Chromatic factory contract or the DAO.
     *      Throws an `ExistMarketSettlementTask` error if a market earning distribution task already exists for the market.
     */
    function createSettlementTask(address market) external override onlyFactoryOrDao {
        if (marketSettlementUpkeepIds[market] != 0) revert ExistMarketSettlementTask();

        marketSettlementUpkeepIds[market] = automate.registerUpkeep(
            address(this),
            2e7, //uint32 gasLimit,
            address(this), // address admin,
            true, // bool useTreasury,
            false, // bool singleExec,
            abi.encode(market)
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
        address market
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
                return (true, abi.encode(market));
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
                return (true, abi.encode(market));
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
                return (true, abi.encode(market));
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
}
