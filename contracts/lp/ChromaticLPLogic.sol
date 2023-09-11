// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {ChromaticLPBase} from "@chromatic-protocol/contracts/lp/ChromaticLPBase.sol";
import {IAutomate, Module, ModuleData} from "@chromatic-protocol/contracts/core/base/gelato/Types.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "@chromatic-protocol/contracts/lp/libraries/ChromaticLPReceipt.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IChromaticLP} from "@chromatic-protocol/contracts/lp/interfaces/IChromaticLP.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ChromaticLPLogicBase} from "@chromatic-protocol/contracts/lp/ChromaticLPLogicBase.sol";

contract ChromaticLPLogic is ChromaticLPLogicBase {
    using Math for uint256;

    event AddLiquidity(
        uint256 indexed receiptId,
        address indexed recipient,
        uint256 oracleVersion,
        uint256 amount
    );

    event AddLiquiditySettled(uint256 indexed receiptId, uint256 lpTokenAmount);

    event RemoveLiquidity(
        uint256 indexed receiptId,
        address indexed recipient,
        uint256 oracleVersion,
        uint256 lpTokenAmount
    );

    event RemoveLiquiditySettled(uint256 indexed receiptId);

    event RebalanceLiquidity(uint256 indexed receiptId);
    event RebalanceSettled(uint256 indexed receiptId);

    constructor()
        ChromaticLPLogicBase(AutomateParam({automate: address(0), opsProxyFactory: address(0)}))
    {}

    function addLiquidity(
        uint256 amount,
        address recipient
    ) external returns (ChromaticLPReceipt memory receipt) {
        receipt = _addLiquidity(amount, recipient);
        emit AddLiquidity({
            receiptId: receipt.id,
            recipient: recipient,
            oracleVersion: receipt.oracleVersion,
            amount: amount
        });
    }

    function removeLiquidity(
        uint256 lpTokenAmount,
        address recipient
    ) external returns (ChromaticLPReceipt memory receipt) {
        uint256[] memory clbTokenAmounts = _calcRemoveClbAmounts(lpTokenAmount);

        receipt = _removeLiquidity(clbTokenAmounts, lpTokenAmount, recipient);
        emit RemoveLiquidity({
            receiptId: receipt.id,
            recipient: recipient,
            oracleVersion: receipt.oracleVersion,
            lpTokenAmount: lpTokenAmount
        });
    }


    function rebalance() public override onlyKeeper {
        uint256 receiptId = _rebalance();
        if (receiptId != 0) {
            emit RebalanceLiquidity({receiptId: receiptId});
            _payKeeperFee();
        }
    }

    function claimLiquidityBatchCallback(
        uint256[] calldata /* receiptIds */,
        int16[] calldata /* feeRates */,
        uint256[] calldata /* depositedAmounts */,
        uint256[] calldata /* mintedCLBTokenAmounts */,
        bytes calldata data
    ) external verifyCallback {
        ChromaticLPReceipt memory receipt = abi.decode(data, (ChromaticLPReceipt));
        if (receipt.recipient != address(this)) {
            (uint256 total, , ) = _poolValue();
            uint256 lpTokenMint = total == receipt.amount
                ? receipt.amount
                : receipt.amount.mulDiv(totalSupply(), total - receipt.amount);
            _mint(receipt.recipient, lpTokenMint);
            emit AddLiquiditySettled({receiptId: receipt.id, lpTokenAmount: lpTokenMint});
        } else {
            emit RebalanceSettled({receiptId: receipt.id});
        }
    }

    function removeLiquidityBatchCallback(
        address clbToken,
        uint256[] calldata clbTokenIds,
        bytes calldata data
    ) external {
        RemoveLiquidityBatchCallbackData memory callbackData = abi.decode(
            data,
            (RemoveLiquidityBatchCallbackData)
        );
        IERC1155(clbToken).safeBatchTransferFrom(
            address(this),
            msg.sender, // market
            clbTokenIds,
            callbackData.clbTokenAmounts,
            bytes("")
        );

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
        int16[] calldata feeRates,
        uint256[] calldata withdrawnAmounts,
        uint256[] calldata burnedCLBTokenAmounts,
        bytes calldata data
    ) external verifyCallback {
        ChromaticLPReceipt memory receipt = abi.decode(data, (ChromaticLPReceipt));

        _decreasePendingClb(feeRates, burnedCLBTokenAmounts);
        // burn and transfer settlementToken

        if (receipt.recipient != address(this)) {
            (uint256 totalValue, , ) = _poolValue();
            uint256 withdrawnAmount;
            for (uint256 i; i < receiptIds.length; ) {
                withdrawnAmount += withdrawnAmounts[i];
                unchecked {
                    i++;
                }
            }
            // (tokenBalance - withdrawn) * (burningLP /totalSupplyLP) + withdrawn
            uint256 balance = IERC20(s_config.market.settlementToken()).balanceOf(address(this));
            uint256 withdrawAmount = (balance - withdrawnAmount).mulDiv(
                receipt.amount,
                totalSupply()
            ) + withdrawnAmount;

            SafeERC20.safeTransfer(
                s_config.market.settlementToken(),
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
                SafeERC20.safeTransfer(IERC20(this), receipt.recipient, leftLpToken);
            }

            emit RemoveLiquiditySettled({receiptId: receipt.id});
        } else {
            emit RebalanceSettled({receiptId: receipt.id});
        }
    }
}
