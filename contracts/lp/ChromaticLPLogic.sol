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
    constructor(
        AutomateParam memory automateParam
    )
        ChromaticLPLogicBase(
            AutomateParam({
                automate: automateParam.automate,
                opsProxyFactory: automateParam.opsProxyFactory
            })
        )
    {}

    /**
     * @dev implementation of IChromaticLP
     */
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

    /**
     * @dev implementation of IChromaticLP
     */
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

    /**
     * @dev implementation of IChromaticLP
     */
    function settle(uint256 receiptId) external returns (bool) {
        return _settle(receiptId);
    }

    /**
     * @dev implementation of IChromaticLP
     */
    function rebalance() external override onlyKeeper {
        uint256 receiptId = _rebalance();
        if (receiptId != 0) {
            emit RebalanceLiquidity({receiptId: receiptId});
            _payKeeperFee();
        }
    }

}
