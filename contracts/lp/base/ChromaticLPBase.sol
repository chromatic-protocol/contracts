// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IChromaticLiquidityCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {IChromaticLP} from "@chromatic-protocol/contracts/lp/interfaces/IChromaticLP.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "@chromatic-protocol/contracts/lp/libraries/ChromaticLPReceipt.sol";
import {IAutomate, Module, ModuleData} from "@chromatic-protocol/contracts/core/base/gelato/Types.sol";
import {AutomateReady} from "@chromatic-protocol/contracts/core/base/gelato/AutomateReady.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";

uint16 constant BPS = 10000;

abstract contract ChromaticLPBase is
    IChromaticLP,
    IChromaticLiquidityCallback,
    ERC20,
    AutomateReady
{
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    struct AddLiquidityBatchCallbackData {
        address provider;
        uint256 liquidityAmount;
        uint256 holdingAmount;
    }

    struct RemoveLiquidityBatchCallbackData {
        address provider;
        uint256 lpTokenAmount;
        uint256[] clbTokenAmounts;
    }

    // configurations
    uint256 private constant DEFAULT_CHECK_REBALANCE_INTERVAL = 30 minutes;
    uint256 private constant DEFAULT_CHECK_SETTLE_INTERVAL = 1 minutes;

    IChromaticMarket public immutable market;
    uint16 public immutable utilizationTargetBPS; // 10000 for 1.0
    uint16 public immutable rebalanceBPS; // 1000 for 0.1

    int16[] public feeRates;
    mapping(int16 => uint16) public distributionRates; // feeRate => distributionRate
    uint256[] private _clbTokenIds;

    uint256 private immutable REBALANCE_CHECKING_INTERVAL;
    uint256 private immutable SETTLE_CHECKING_INTERVAL;
    bytes32 private _rebalanceTaskId;
    bytes32 private _settleTaskId;

    uint256 _receiptId;
    mapping(uint256 => ChromaticLPReceipt) public receipts; // receiptId => receipt
    // mapping(uint256 => address) _providerMap; // receiptId => provider
    // mapping(address => EnumerableSet.UintSet) _providerReceiptIds; // provider => receiptIds
    mapping(uint256 => EnumerableSet.UintSet) _lpReceiptMap; // receiptId => lpReceiptIds

    EnumerableSet.UintSet pendingAddReceipts; // set of ChromaticLPReceipts with ADD_LIQUIDITY
    EnumerableSet.UintSet pendingRemoveReceipts; // set of ChromaticLPReceipts with REMOVE_LIQUIDITY
    EnumerableSet.UintSet pendingAddPoolReceipts; // set of ChromaticLPReceipts with ADD_LIQUIDITY
    EnumerableSet.UintSet pendingRemovePoolReceipts; // set of ChromaticLPReceipts with REMOVE_LIQUIDITY

    error InvalidUtilizationTarget(uint16 targetBPS);
    error InvalidRebalanceBPS();
    error NotMatchDistributionLength(uint256 feeLength, uint256 distributionLength);
    error InvalidDistributionSum();
    error AlreadyRebalanceTaskExist();

    error NotMarket();
    error OnlyBatchCall();

    modifier verifyCallback() {
        if (address(market) != msg.sender) revert NotMarket();
        _;
    }

    constructor(
        IChromaticMarket _market,
        uint16 _utilizationTargetBPS,
        uint16 _rebalanceBPS,
        int16[] memory _feeRates,
        uint16[] memory _distributionRates,
        uint256 rebalanceCheckingInterval,
        uint256 settleCheckingInterval,
        address _automate,
        address opsProxyFactory
    ) ERC20("", "") AutomateReady(_automate, address(this), opsProxyFactory) {
        if (_utilizationTargetBPS > BPS) revert InvalidUtilizationTarget(_utilizationTargetBPS);
        if (_feeRates.length != _distributionRates.length)
            revert NotMatchDistributionLength(_feeRates.length, _distributionRates.length);

        if (_utilizationTargetBPS <= _rebalanceBPS) revert InvalidRebalanceBPS();

        market = _market;
        utilizationTargetBPS = _utilizationTargetBPS;
        rebalanceBPS = _rebalanceBPS;
        feeRates = _feeRates;

        uint16 totalRate;
        for (uint256 i; i < _distributionRates.length; ) {
            distributionRates[_feeRates[i]] = _distributionRates[i];
            totalRate += _distributionRates[i];

            unchecked {
                i++;
            }
        }
        feeRates = _feeRates;
        if (totalRate != BPS) revert InvalidDistributionSum();
        REBALANCE_CHECKING_INTERVAL = rebalanceCheckingInterval;
        SETTLE_CHECKING_INTERVAL = settleCheckingInterval;

        // set clbTokenIds
        _clbTokenIds = new uint256[](_feeRates.length);
        for (uint256 i; i < _feeRates.length; ) {
            _clbTokenIds[i] = CLBTokenLib.encodeId(_feeRates[i]);

            unchecked {
                i++;
            }
        }

        // FIXME call later after first addLiquidity called
        createRebalanceTask();
    }

    function createRebalanceTask() internal {
        if (_rebalanceTaskId != 0) revert AlreadyRebalanceTaskExist();

        ModuleData memory moduleData = ModuleData({modules: new Module[](3), args: new bytes[](3)});
        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.TIME;
        moduleData.modules[2] = Module.PROXY;
        moduleData.args[0] = abi.encode(address(this), abi.encodeCall(this.resolveRebalance, ()));
        moduleData.args[1] = abi.encode(
            uint128(block.timestamp + REBALANCE_CHECKING_INTERVAL),
            uint128(REBALANCE_CHECKING_INTERVAL)
        );
        moduleData.args[2] = bytes("");

        _rebalanceTaskId = automate.createTask(
            address(this),
            abi.encode(this.rebalance.selector), // FIXME
            moduleData,
            ETH
        );
    }

    function cancelRebalanceTask() internal {
        // FIXME
        automate.cancelTask(_rebalanceTaskId);
        _rebalanceTaskId = 0;
    }

    function resolveRebalance() external view returns (bool, bytes memory) {
        // check value of this
        // check utilization

        uint256 reservedToken = IERC20(market.settlementToken()).balanceOf(address(this));
        uint256 clbValue = totalClbValue();
        uint256 total = reservedToken + clbValue;
        if (total == 0) return (false, "");
        uint256 currentUtility = clbValue.mulDiv(BPS, total);
        if (uint256(utilizationTargetBPS + rebalanceBPS) > currentUtility) {
            return (true, "");
        } else if (uint256(utilizationTargetBPS - rebalanceBPS) < currentUtility) {
            return (true, "");
        }
        return (false, "");
    }

    function rebalance() external {
        uint256 reservedToken = IERC20(market.settlementToken()).balanceOf(address(this));
        uint256 clbValue = totalClbValue();
        uint256 total = reservedToken + clbValue;
        if (total == 0) return;
        uint256 currentUtility = clbValue.mulDiv(BPS, reservedToken + clbValue);
        if (uint256(utilizationTargetBPS + rebalanceBPS) > currentUtility) {
            uint256[] memory _clbTokenBalances = clbTokenBalances();
            uint256[] memory clbTokenAmounts = new uint256[](feeRates.length);
            for (uint256 i; i < feeRates.length; i++) {
                clbTokenAmounts[i] = _clbTokenBalances[i].mulDiv(rebalanceBPS, currentUtility);
            }
            _removeLiquidity(clbTokenAmounts, 0, address(this));
        } else if (uint256(utilizationTargetBPS - rebalanceBPS) < currentUtility) {
            addLiquidity(total.mulDiv(rebalanceBPS, BPS), address(this));
        }
    }

    function clbTokenBalances() public view returns (uint256[] memory _clbTokenBalances) {
        address[] memory _owners = new address[](feeRates.length);
        for (uint256 i; i < feeRates.length; ) {
            _owners[i] = address(this);
            unchecked {
                i++;
            }
        }
        _clbTokenBalances = IERC1155(market.clbToken()).balanceOfBatch(_owners, _clbTokenIds);
    }

    function totalClbValue() public view returns (uint256 totalValue) {
        uint256[] memory clbSupplies = market.clbToken().totalSupplyBatch(_clbTokenIds);
        uint256[] memory binValues = market.getBinValues(feeRates);
        uint256[] memory _clbTokenBalances = clbTokenBalances();

        for (uint256 i; i < binValues.length; i++) {
            totalValue += _clbTokenBalances[i].mulDiv(binValues[i], clbSupplies[i]);
        }
    }

    function addLiquidity(
        uint256 amount,
        address recipient
    ) public override returns (ChromaticLPReceipt memory receipt) {
        (uint256[] memory amounts, uint256 liquidityAmount) = _distributeAmount(
            amount.mulDiv(utilizationTargetBPS, BPS)
        );

        LpReceipt[] memory lpReceipts = market.addLiquidityBatch(
            recipient,
            feeRates,
            amounts,
            abi.encode(
                AddLiquidityBatchCallbackData({
                    provider: msg.sender,
                    liquidityAmount: liquidityAmount,
                    holdingAmount: amount - liquidityAmount
                })
            )
        );

        receipt = ChromaticLPReceipt({
            id: nextReceiptId(),
            oracleVersion: lpReceipts[0].oracleVersion,
            amount: amount,
            recipient: recipient,
            action: ChromaticLPAction.ADD_LIQUIDITY
        });

        receipts[receipt.id] = receipt;
        EnumerableSet.UintSet storage lpReceiptIdSet = _lpReceiptMap[receipt.id];
        for (uint256 i; i < lpReceipts.length; ) {
            lpReceiptIdSet.add(lpReceipts[i].id);

            unchecked {
                i++;
            }
        }
        // store receipt to call claim and transfer
        pendingAddReceipts.add(receipt.id);

        emit AddLiquidity({
            receiptId: receipt.id,
            recipient: recipient,
            oracleVersion: receipt.oracleVersion,
            amount: amount
        });

        // create TASK
        createSettleTask();
    }

    function addLiquidityBatchCallback(
        address _settlementToken,
        address vault,
        bytes calldata data
    ) external override verifyCallback {
        AddLiquidityBatchCallbackData memory callbackData = abi.decode(
            data,
            (AddLiquidityBatchCallbackData)
        );
        //slither-disable-next-line arbitrary-send-erc20
        SafeERC20.safeTransferFrom(
            IERC20(_settlementToken),
            callbackData.provider,
            vault,
            callbackData.liquidityAmount
        );
        SafeERC20.safeTransferFrom(
            IERC20(_settlementToken),
            callbackData.provider,
            address(this),
            callbackData.holdingAmount
        );
    }

    function removeLiquidity(
        uint256 lpTokenAmount,
        address recipient
    ) external override returns (ChromaticLPReceipt memory receipt) {
        int16[] memory _feeRates = feeRates;

        address[] memory _owners = new address[](_feeRates.length);
        for (uint256 i; i < _feeRates.length; ) {
            _owners[i] = address(this);
            unchecked {
                i++;
            }
        }
        uint256[] memory _clbTokenBalances = IERC1155(market.clbToken()).balanceOfBatch(
            _owners,
            _clbTokenIds
        );

        uint256[] memory clbTokenAmounts = new uint256[](_clbTokenBalances.length);
        for (uint256 i; i < _clbTokenBalances.length; ) {
            clbTokenAmounts[i] = _clbTokenBalances[i].mulDiv(
                lpTokenAmount,
                totalSupply(),
                Math.Rounding.Up
            );

            unchecked {
                i++;
            }
        }
        receipt = _removeLiquidity(clbTokenAmounts, lpTokenAmount, recipient);
    }

    function _removeLiquidity(
        uint256[] memory clbTokenAmounts,
        uint256 lpTokenAmount,
        address recipient
    ) internal returns (ChromaticLPReceipt memory receipt) {
        LpReceipt[] memory lpReceipts = market.removeLiquidityBatch(
            recipient,
            feeRates,
            clbTokenAmounts,
            abi.encode(
                RemoveLiquidityBatchCallbackData({
                    provider: msg.sender,
                    lpTokenAmount: lpTokenAmount,
                    clbTokenAmounts: clbTokenAmounts
                })
            )
        );

        receipt = ChromaticLPReceipt({
            id: nextReceiptId(),
            oracleVersion: lpReceipts[0].oracleVersion,
            amount: lpTokenAmount,
            recipient: recipient,
            action: ChromaticLPAction.REMOVE_LIQUIDITY
        });

        receipts[receipt.id] = receipt;
        EnumerableSet.UintSet storage lpReceiptIdSet = _lpReceiptMap[receipt.id];
        for (uint256 i; i < lpReceipts.length; ) {
            lpReceiptIdSet.add(lpReceipts[i].id);

            unchecked {
                i++;
            }
        }
        // store receipt to call claim and transfer
        pendingRemoveReceipts.add(receipt.id);

        emit RemoveLiquidity({
            receiptId: receipt.id,
            recipient: recipient,
            oracleVersion: receipt.oracleVersion,
            lpTokenAmount: lpTokenAmount
        });

        createSettleTask();
    }

    function createSettleTask() internal {
        if (_settleTaskId != 0) return;

        ModuleData memory moduleData = ModuleData({modules: new Module[](3), args: new bytes[](3)});
        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.TIME;
        moduleData.modules[2] = Module.PROXY;
        moduleData.args[0] = abi.encode(address(this), abi.encodeCall(this.resolveSettle, ()));
        moduleData.args[1] = abi.encode(
            uint128(block.timestamp + SETTLE_CHECKING_INTERVAL),
            uint128(SETTLE_CHECKING_INTERVAL)
        );
        moduleData.args[2] = bytes("");

        _rebalanceTaskId = automate.createTask(
            address(this),
            abi.encode(this.settle.selector), // FIXME
            moduleData,
            ETH
        );
    }

    function resolveSettle() external view returns (bool, bytes memory) {
        // check oracle increased
        // check any pending add / remove exist

        // TODO for pendingRemoveReceipts for pendingPool

        if (pendingAddReceipts.length() == 0 && pendingRemoveReceipts.length() == 0) {
            return (false, bytes(""));
        }
        IOracleProvider.OracleVersion memory currentOracle = market
            .oracleProvider()
            .currentVersion();

        for (uint256 i = 0; i < pendingAddReceipts.length(); i++) {
            uint256 receiptId = pendingAddReceipts.at(i);
            ChromaticLPReceipt memory receipt = receipts[receiptId];
            if (receipt.oracleVersion < currentOracle.version) {
                return (true, bytes(""));
            }
        }
        for (uint256 i = 0; i < pendingRemoveReceipts.length(); i++) {
            uint256 receiptId = pendingRemoveReceipts.at(i);
            ChromaticLPReceipt memory receipt = receipts[receiptId];
            if (receipt.oracleVersion < currentOracle.version) {
                return (true, bytes(""));
            }
        }

        // for pending add/remove by user and by self
        return (false, bytes(""));
    }

    function cancelSettleTask() internal {
        if (_settleTaskId != 0) {
            automate.cancelTask(_settleTaskId);
            _settleTaskId = 0;
        }
    }

    function settle() public {
        _settleAddLiquidity();
        _settleRemoveLiquidity();
        // finally remove settle task
        cancelSettleTask();
    }

    function _settleAddLiquidity() internal {
        IOracleProvider.OracleVersion memory currentOracle = market
            .oracleProvider()
            .currentVersion();
        uint256[] memory receiptIds = pendingAddReceipts.values();
        for (uint256 i = 0; i < receiptIds.length; i++) {
            ChromaticLPReceipt memory receipt = receipts[receiptIds[i]];
            if (receipt.oracleVersion >= currentOracle.version) {
                break; // acending order
            }
            // do claim
            // TODO pass calldata with receipt id
            market.claimLiquidityBatch(_lpReceiptMap[receipt.id].values(), bytes(""));

            // TODO mint and transfer lp pool token to provider

            // remove receipts in callback??
            delete _lpReceiptMap[receipt.id];
            pendingAddReceipts.remove(receipt.id);
            delete receipts[receipt.id];
        }
    }

    function _settleRemoveLiquidity() internal {
        IOracleProvider.OracleVersion memory currentOracle = market
            .oracleProvider()
            .currentVersion();
        uint256[] memory receiptIds = pendingRemoveReceipts.values();
        for (uint256 i = 0; i < receiptIds.length; i++) {
            ChromaticLPReceipt memory receipt = receipts[receiptIds[i]];
            if (receipt.oracleVersion >= currentOracle.version) {
                break; // acending order
            }
            // do claim
            // TODO pass calldata with receipt id
            market.withdrawLiquidityBatch(_lpReceiptMap[receipt.id].values(), bytes(""));

            // TODO mint and transfer lp pool token to provider

            // remove receipts in callback??
            delete _lpReceiptMap[receipt.id];
            pendingAddReceipts.remove(receipt.id);
            delete receipts[receipt.id];
        }
    }

    function claimLiquidityBatchCallback(
        uint256[] calldata receiptIds,
        int16[] calldata _feeRates,
        uint256[] calldata depositedAmounts,
        uint256[] calldata mintedCLBTokenAmounts,
        bytes calldata
    ) external override verifyCallback {
        for (uint256 i; i < receiptIds.length; ) {
            uint256 receiptId = receiptIds[i];
            // address provider = _providerMap[receiptId];

            //slither-disable-next-line unused-return
            // _providerReceiptIds[provider].remove(receiptId);
            // delete _providerMap[receiptId];
            delete receipts[receiptId];

            unchecked {
                i++;
            }
        }
    }

    function removeLiquidityBatchCallback(
        address clbToken,
        uint256[] calldata clbTokenIds,
        bytes calldata data
    ) external pure override {}

    function withdrawLiquidityBatchCallback(
        uint256[] calldata receiptIds,
        int16[] calldata _feeRates,
        uint256[] calldata withdrawnAmounts,
        uint256[] calldata burnedCLBTokenAmounts,
        bytes calldata data
    ) external override verifyCallback {
        for (uint256 i; i < receiptIds.length; ) {
            uint256 receiptId = receiptIds[i];
            // address provider = _providerMap[receiptId];

            //slither-disable-next-line unused-return
            // _providerReceiptIds[provider].remove(receiptId);
            // delete _providerMap[receiptId];
            delete receipts[receiptId];

            unchecked {
                i++;
            }
        }
    }

    function _distributeAmount(
        uint256 amount
    ) private view returns (uint256[] memory amounts, uint256 totalAmount) {
        int16[] memory _feeRates = feeRates;
        amounts = new uint256[](_feeRates.length);
        for (uint256 i = 0; i < _feeRates.length; ) {
            uint256 _amount = amount.mulDiv(distributionRates[_feeRates[i]], BPS);

            amounts[i] = _amount;
            totalAmount += _amount;

            unchecked {
                i++;
            }
        }
    }

    function nextReceiptId() private returns (uint256 id) {
        id = ++_receiptId;
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function markets() external view override returns (address[] memory _markets) {
        _markets = new address[](1);
        _markets[0] = address(market);
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function settlementToken() external view override returns (address) {
        return address(market.settlementToken());
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function lpToken() external view override returns (address) {
        return address(this);
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function getReceipts(
        address owner
    ) external view override returns (ChromaticLPReceipt[] memory) {
        // TODO
    }

    /**
     * @inheritdoc ERC20
     */
    function name() public view virtual override returns (string memory) {
        return
            string(abi.encodePacked("ChromaticPassiveLP - ", _tokenSymbol(), " - ", _indexName()));
    }

    /**
     * @inheritdoc ERC20
     */
    function symbol() public view virtual override returns (string memory) {
        return string(abi.encodePacked("cp", _tokenSymbol(), " - ", _indexName()));
    }

    /**
     * @inheritdoc ERC20
     */
    function decimals() public view virtual override returns (uint8) {
        return market.settlementToken().decimals();
    }

    function _tokenSymbol() private view returns (string memory) {
        return market.settlementToken().symbol();
    }

    function _indexName() private view returns (string memory) {
        return market.oracleProvider().description();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function addLiquidityCallback(address, address, bytes calldata) external pure override {
        revert OnlyBatchCall();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function claimLiquidityCallback(
        uint256,
        int16,
        uint256,
        uint256,
        bytes calldata
    ) external pure override {
        revert OnlyBatchCall();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function removeLiquidityCallback(address, uint256, bytes calldata) external pure override {
        revert OnlyBatchCall();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function withdrawLiquidityCallback(
        uint256,
        int16,
        uint256,
        uint256,
        bytes calldata
    ) external pure override {
        revert OnlyBatchCall();
    }
}
