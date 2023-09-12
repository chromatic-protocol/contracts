// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "@chromatic-protocol/contracts/lp/libraries/ChromaticLPReceipt.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {ChromaticLPStorage} from "@chromatic-protocol/contracts/lp/ChromaticLPStorage.sol";

abstract contract ChromaticLPBase is ChromaticLPStorage {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    error InvalidUtilizationTarget(uint16 targetBPS);
    error InvalidRebalanceBPS();
    error NotMatchDistributionLength(uint256 feeLength, uint256 distributionLength);
    error InvalidDistributionSum();

    error NotMarket();
    error OnlyBatchCall();

    error UnknownLPAction();
    error NotOwner();
    error AlreadySwapRouterConfigured();
    error NotKeeperCalled();
    error AlreadyRebalanceTaskExist();

    constructor(AutomateParam memory automateParam) ChromaticLPStorage(automateParam) {}

    function _initialize(
        Config memory config,
        int16[] memory feeRates,
        uint16[] memory distributionRates
    ) internal {
        _validateConfig(
            config.utilizationTargetBPS,
            config.rebalanceBPS,
            feeRates,
            distributionRates
        );
        s_config = Config({
            market: config.market,
            utilizationTargetBPS: config.utilizationTargetBPS,
            rebalanceBPS: config.rebalanceBPS,
            rebalnceCheckingInterval: config.rebalnceCheckingInterval,
            settleCheckingInterval: config.settleCheckingInterval
        });
        _setupState(feeRates, distributionRates);
    }

    function _validateConfig(
        uint16 utilizationTargetBPS,
        uint16 rebalanceBPS,
        int16[] memory feeRates,
        uint16[] memory distributionRates
    ) private pure {
        if (utilizationTargetBPS > BPS) revert InvalidUtilizationTarget(utilizationTargetBPS);
        if (feeRates.length != distributionRates.length)
            revert NotMatchDistributionLength(feeRates.length, distributionRates.length);

        if (utilizationTargetBPS <= rebalanceBPS) revert InvalidRebalanceBPS();
    }

    function _setupState(int16[] memory feeRates, uint16[] memory distributionRates) private {
        uint16 totalRate;
        for (uint256 i; i < distributionRates.length; ) {
            s_state.distributionRates[feeRates[i]] = distributionRates[i];
            totalRate += distributionRates[i];

            unchecked {
                i++;
            }
        }
        if (totalRate != BPS) revert InvalidDistributionSum();
        s_state.feeRates = feeRates;

        _setupClbTokenIds(feeRates);
    }

    function _setupClbTokenIds(int16[] memory feeRates) private {
        s_state.clbTokenIds = new uint256[](feeRates.length);
        for (uint256 i; i < feeRates.length; ) {
            s_state.clbTokenIds[i] = CLBTokenLib.encodeId(feeRates[i]);

            unchecked {
                i++;
            }
        }
    }

    /**
     * @inheritdoc ERC20
     */
    function name() public view virtual override returns (string memory) {
        return string(abi.encodePacked("ChromaticLP - ", _tokenSymbol(), " - ", _indexName()));
    }

    /**
     * @inheritdoc ERC20
     */
    function symbol() public view virtual override returns (string memory) {
        return string(abi.encodePacked("cp", _tokenSymbol(), " - ", _indexName()));
    }

    function _tokenSymbol() private view returns (string memory) {
        return s_config.market.settlementToken().symbol();
    }

    function _indexName() private view returns (string memory) {
        return s_config.market.oracleProvider().description();
    }

    function _resolveRebalance(
        function() external _rebalance
    ) internal view returns (bool, bytes memory) {
        (uint256 total, uint256 clbValue, ) = _poolValue();

        if (total == 0) return (false, bytes(""));
        uint256 currentUtility = clbValue.mulDiv(BPS, total);
        if (uint256(s_config.utilizationTargetBPS + s_config.rebalanceBPS) > currentUtility) {
            return (true, abi.encodeCall(_rebalance, ()));
        } else if (
            uint256(s_config.utilizationTargetBPS - s_config.rebalanceBPS) < currentUtility
        ) {
            return (true, abi.encodeCall(_rebalance, ()));
        }
        return (false, bytes(""));
    }

    function _resolveSettle(
        uint256 receiptId,
        function(uint256) external settleTask
    ) internal view returns (bool, bytes memory) {
        IOracleProvider.OracleVersion memory currentOracle = s_config
            .market
            .oracleProvider()
            .currentVersion();

        ChromaticLPReceipt memory receipt = s_state.receipts[receiptId];
        if (receipt.id > 0 && receipt.oracleVersion < currentOracle.version) {
            return (true, abi.encodeCall(settleTask, (receiptId)));
        }

        // for pending add/remove by user and by self
        return (false, bytes(""));
    }
}
