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

contract ChromaticLPBase is IChromaticLP, IChromaticLiquidityCallback, ERC20, AutomateReady {
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

    IChromaticMarket internal immutable _market;
    uint16 public immutable utilizationTargetBPS; // 10000 for 1.0
    uint16 public immutable rebalanceBPS; // 1000 for 0.1

    int16[] public feeRates;
    mapping(int16 => uint16) public distributionRates; // feeRate => distributionRate
    uint256[] private _clbTokenIds;

    uint256 private immutable REBALANCE_CHECKING_INTERVAL;
    uint256 private immutable SETTLE_CHECKING_INTERVAL;
    bytes32 private _rebalanceTaskId;

    mapping(uint256 => bytes32) _receiptSettleTaskIds;

    uint256 _receiptId;
    mapping(uint256 => ChromaticLPReceipt) public receipts; // receiptId => receipt
    mapping(uint256 => EnumerableSet.UintSet) _lpReceiptMap; // receiptId => lpReceiptIds

    mapping(uint256 => address) _providerMap; // receiptId => provider
    mapping(address => EnumerableSet.UintSet) _providerReceiptIds; // provider => receiptIds

    error InvalidUtilizationTarget(uint16 targetBPS);
    error InvalidRebalanceBPS();
    error NotMatchDistributionLength(uint256 feeLength, uint256 distributionLength);
    error InvalidDistributionSum();
    error AlreadyRebalanceTaskExist();

    error NotMarket();
    error OnlyBatchCall();

    error UnknownLPAction();

    modifier verifyCallback() {
        if (address(_market) != msg.sender) revert NotMarket();
        _;
    }

    constructor(
        IChromaticMarket marketAddress,
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

        _market = marketAddress;
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
            abi.encode(this.rebalance.selector),
            moduleData,
            ETH
        );
    }

    function cancelRebalanceTask() internal {
        if (_rebalanceTaskId != 0) {
            automate.cancelTask(_rebalanceTaskId);
            _rebalanceTaskId = 0;
        }
    }

    function resolveRebalance() external view returns (bool, bytes memory) {
        (uint256 total, uint256 clbValue, ) = poolValue();

        if (total == 0) return (false, bytes(""));
        uint256 currentUtility = clbValue.mulDiv(BPS, total);
        if (uint256(utilizationTargetBPS + rebalanceBPS) > currentUtility) {
            return (true, abi.encodeCall(this.rebalance, ()));
        } else if (uint256(utilizationTargetBPS - rebalanceBPS) < currentUtility) {
            return (true, abi.encodeCall(this.rebalance, ()));
        }
        return (false, bytes(""));
    }

    function rebalance() external {
        (uint256 total, uint256 clbValue, ) = poolValue();

        if (total == 0) return;
        uint256 currentUtility = clbValue.mulDiv(BPS, total);
        if (uint256(utilizationTargetBPS + rebalanceBPS) > currentUtility) {
            uint256[] memory _clbTokenBalances = clbTokenBalances();
            uint256[] memory clbTokenAmounts = new uint256[](feeRates.length);
            for (uint256 i; i < feeRates.length; i++) {
                clbTokenAmounts[i] = _clbTokenBalances[i].mulDiv(rebalanceBPS, currentUtility);
            }
            ChromaticLPReceipt memory receipt = _removeLiquidity(clbTokenAmounts, 0, address(this));

            emit RebalanceLiquidity({receiptId: receipt.id});
        } else if (uint256(utilizationTargetBPS - rebalanceBPS) < currentUtility) {
            ChromaticLPReceipt memory receipt = _addLiquidity(
                total.mulDiv(rebalanceBPS, BPS),
                address(this)
            );
            emit RebalanceLiquidity({receiptId: receipt.id});
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
        _clbTokenBalances = IERC1155(_market.clbToken()).balanceOfBatch(_owners, _clbTokenIds);
    }

    function poolClbValue() public view returns (uint256 value) {
        value = calcClbValue(clbTokenBalances());
    }

    function poolValue()
        public
        view
        returns (uint256 totalValue, uint256 clbValue, uint256 holdingValue)
    {
        holdingValue = IERC20(_market.settlementToken()).balanceOf(address(this));
        clbValue = poolClbValue();
        totalValue = holdingValue + clbValue;
    }

    function addLiquidity(
        uint256 amount,
        address recipient
    ) public override returns (ChromaticLPReceipt memory receipt) {
        receipt = _addLiquidity(amount, recipient);
        emit AddLiquidity({
            receiptId: receipt.id,
            recipient: recipient,
            oracleVersion: receipt.oracleVersion,
            amount: amount
        });
    }

    function _addLiquidity(
        uint256 amount,
        address recipient
    ) internal returns (ChromaticLPReceipt memory receipt) {
        (uint256[] memory amounts, uint256 liquidityAmount) = _distributeAmount(
            amount.mulDiv(utilizationTargetBPS, BPS)
        );

        LpReceipt[] memory lpReceipts = _market.addLiquidityBatch(
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

        _addReceipt(receipt, lpReceipts);

        createSettleTask(receipt.id);
    }

    function _addReceipt(
        ChromaticLPReceipt memory receipt,
        LpReceipt[] memory lpReceipts
    ) internal {
        receipts[receipt.id] = receipt;
        EnumerableSet.UintSet storage lpReceiptIdSet = _lpReceiptMap[receipt.id];
        for (uint256 i; i < lpReceipts.length; ) {
            lpReceiptIdSet.add(lpReceipts[i].id);

            unchecked {
                i++;
            }
        }

        _providerMap[receipt.id] = msg.sender;
        EnumerableSet.UintSet storage receiptIdSet = _providerReceiptIds[msg.sender];
        receiptIdSet.add(receipt.id);
    }

    function _removeReceipt(uint256 receiptId) internal {
        delete receipts[receiptId];
        delete _lpReceiptMap[receiptId];
        address provider = _providerMap[receiptId];
        EnumerableSet.UintSet storage receiptIdSet = _providerReceiptIds[provider];
        receiptIdSet.remove(receiptId);
        delete _providerMap[receiptId];
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

        if (callbackData.provider != address(this)) {
            SafeERC20.safeTransferFrom(
                IERC20(_settlementToken),
                callbackData.provider,
                address(this),
                callbackData.holdingAmount
            );
        }
    }

    function removeLiquidity(
        uint256 lpTokenAmount,
        address recipient
    ) external override returns (ChromaticLPReceipt memory receipt) {
        uint256[] memory clbTokenAmounts = _calcRemoveClbAmounts(lpTokenAmount);

        receipt = _removeLiquidity(clbTokenAmounts, lpTokenAmount, recipient);
        emit RemoveLiquidity({
            receiptId: receipt.id,
            recipient: recipient,
            oracleVersion: receipt.oracleVersion,
            lpTokenAmount: lpTokenAmount
        });
    }

    function _calcRemoveClbAmounts(
        uint256 lpTokenAmount
    ) internal view returns (uint256[] memory clbTokenAmounts) {
        int16[] memory _feeRates = feeRates;

        address[] memory _owners = new address[](_feeRates.length);
        for (uint256 i; i < _feeRates.length; ) {
            _owners[i] = address(this);
            unchecked {
                i++;
            }
        }
        uint256[] memory _clbTokenBalances = IERC1155(_market.clbToken()).balanceOfBatch(
            _owners,
            _clbTokenIds
        );

        clbTokenAmounts = new uint256[](_clbTokenBalances.length);
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
    }

    function _removeLiquidity(
        uint256[] memory clbTokenAmounts,
        uint256 lpTokenAmount,
        address recipient
    ) internal returns (ChromaticLPReceipt memory receipt) {
        LpReceipt[] memory lpReceipts = _market.removeLiquidityBatch(
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

        _addReceipt(receipt, lpReceipts);

        createSettleTask(receipt.id);
    }

    function createSettleTask(uint256 receiptId) internal {
        if (_receiptSettleTaskIds[receiptId] != 0) return;

        ModuleData memory moduleData = ModuleData({modules: new Module[](3), args: new bytes[](3)});
        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.TIME;
        moduleData.modules[2] = Module.PROXY;
        moduleData.args[0] = abi.encode(
            address(this),
            abi.encodeCall(this.resolveSettle, (receiptId))
        );
        moduleData.args[1] = abi.encode(
            uint128(block.timestamp + SETTLE_CHECKING_INTERVAL),
            uint128(SETTLE_CHECKING_INTERVAL)
        );
        moduleData.args[2] = bytes("");

        _receiptSettleTaskIds[receiptId] = automate.createTask(
            address(this),
            abi.encode(this.settle.selector),
            moduleData,
            ETH
        );
    }

    function resolveSettle(uint256 receiptId) external view returns (bool, bytes memory) {
        IOracleProvider.OracleVersion memory currentOracle = _market
            .oracleProvider()
            .currentVersion();

        ChromaticLPReceipt memory receipt = receipts[receiptId];
        if (receipt.id > 0 && receipt.oracleVersion < currentOracle.version) {
            return (true, abi.encodeCall(this.settle, (receiptId)));
        }

        // for pending add/remove by user and by self
        return (false, bytes(""));
    }

    function cancelSettleTask(uint256 receiptId) internal {
        if (_receiptSettleTaskIds[receiptId] != 0) {
            automate.cancelTask(_receiptSettleTaskIds[receiptId]);
            delete _receiptSettleTaskIds[receiptId];
        }
    }

    function settle(uint256 receiptId) public {
        ChromaticLPReceipt memory receipt = receipts[receiptId];
        IOracleProvider.OracleVersion memory currentOracle = _market
            .oracleProvider()
            .currentVersion();
        // TODO check receipt
        if (receipt.oracleVersion >= currentOracle.version) {
            if (receipt.action == ChromaticLPAction.ADD_LIQUIDITY) {
                _settleAddLiquidity(receipt);
            } else if (receipt.action == ChromaticLPAction.REMOVE_LIQUIDITY) {
                _settleRemoveLiquidity(receipt);
            } else {
                revert UnknownLPAction();
            }
            // finally remove settle task
            cancelSettleTask(receiptId);
        }
    }

    function _settleAddLiquidity(ChromaticLPReceipt memory receipt) internal {
        // pass ChromaticLPReceipt as calldata
        // mint and transfer lp pool token to provider in callback
        _market.claimLiquidityBatch(_lpReceiptMap[receipt.id].values(), abi.encode(receipt));

        _removeReceipt(receipt.id);
    }

    function _settleRemoveLiquidity(ChromaticLPReceipt memory receipt) internal {
        // do claim
        // pass ChromaticLPReceipt as calldata
        _market.withdrawLiquidityBatch(_lpReceiptMap[receipt.id].values(), abi.encode(receipt));

        _removeReceipt(receipt.id);
    }

    function claimLiquidityBatchCallback(
        uint256[] calldata receiptIds,
        int16[] calldata _feeRates,
        uint256[] calldata depositedAmounts,
        uint256[] calldata mintedCLBTokenAmounts,
        bytes calldata data
    ) external override verifyCallback {
        ChromaticLPReceipt memory receipt = abi.decode(data, (ChromaticLPReceipt));
        if (receipt.recipient != address(this)) {
            // uint256 clbValue = calcClbValue(mintedCLBTokenAmounts);
            (uint256 total, , ) = poolValue();
            uint256 lpTokenMint = total == 0
                ? receipt.amount
                : receipt.amount.mulDiv(totalSupply(), total - receipt.amount);
            _mint(receipt.recipient, lpTokenMint);
            emit AddLiquiditySettled({receiptId: receipt.id, lpTokenAmount: lpTokenMint});
        } else {
            emit RebalanceSettled({receiptId: receipt.id});
        }
    }

    function calcClbValue(
        uint256[] memory clbTokenAmounts
    ) public view returns (uint256 totalValue) {
        uint256[] memory clbSupplies = _market.clbToken().totalSupplyBatch(_clbTokenIds);
        uint256[] memory binValues = _market.getBinValues(feeRates);

        for (uint256 i; i < binValues.length; ) {
            totalValue += clbTokenAmounts[i].mulDiv(binValues[i], clbSupplies[i]);
            unchecked {
                i++;
            }
        }
    }

    function removeLiquidityBatchCallback(
        address clbToken,
        uint256[] calldata clbTokenIds,
        bytes calldata data
    ) external override {
        RemoveLiquidityBatchCallbackData memory callbackData = abi.decode(
            data,
            (RemoveLiquidityBatchCallbackData)
        );
        callbackData.lpTokenAmount;
        if (callbackData.provider != address(this)) {
            SafeERC20.safeTransferFrom(
                IERC20(this),
                callbackData.provider,
                address(this),
                callbackData.lpTokenAmount
            );
        }
    }

    function withdrawLiquidityBatchCallback(
        uint256[] calldata receiptIds,
        int16[] calldata _feeRates,
        uint256[] calldata withdrawnAmounts,
        uint256[] calldata burnedCLBTokenAmounts,
        bytes calldata data
    ) external override verifyCallback {
        ChromaticLPReceipt memory receipt = abi.decode(data, (ChromaticLPReceipt));
        // burn and transfer settlementToken
        if (receipt.recipient != address(this)) {
            (uint256 totalValue, uint256 clbValue, uint256 holdingValue) = poolValue();
            uint256 withdrawnAmount;
            for (uint256 i; i < receiptIds.length; ) {
                withdrawnAmount += withdrawnAmounts[i];
                unchecked {
                    i++;
                }
            }
            // (tokenBalance - withdrawn) * (burningLP /totalSupplyLP) + withdrawn
            uint256 balance = IERC20(_market.settlementToken()).balanceOf(address(this));
            uint256 withdrawAmount = (balance - withdrawnAmount).mulDiv(
                receipt.amount,
                totalSupply()
            ) + withdrawnAmount;

            SafeERC20.safeTransferFrom(
                _market.settlementToken(),
                address(this),
                receipt.recipient,
                withdrawAmount
            );
            // burningLP: withdrawAmount = totalSupply: totalValue
            // burningLP = withdrawAmount * totalSupply / totalValue
            // burn LPToken requested
            uint256 burningAmount = withdrawAmount.mulDiv(totalSupply(), totalValue);
            _burn(address(this), burningAmount);

            // transfer left lpTokens
            uint256 leftLpToken = receipt.amount - burningAmount;
            if (leftLpToken > 0) {
                SafeERC20.safeTransferFrom(
                    IERC20(this),
                    address(this),
                    receipt.recipient,
                    leftLpToken
                );
            }

            emit RemoveLiquiditySettled({receiptId: receipt.id});
        } else {
            emit RebalanceSettled({receiptId: receipt.id});
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
    function market() external view override returns (address) {
        return address(_market);
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function settlementToken() external view override returns (address) {
        return address(_market.settlementToken());
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
        return _market.settlementToken().decimals();
    }

    function _tokenSymbol() private view returns (string memory) {
        return _market.settlementToken().symbol();
    }

    function _indexName() private view returns (string memory) {
        return _market.oracleProvider().description();
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
