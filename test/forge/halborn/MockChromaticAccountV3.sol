// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IChromaticTradeCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticTradeCallback.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {IChromaticAccount} from "@chromatic-protocol/contracts/periphery/interfaces/IChromaticAccount.sol";
import {OpenPositionInfo, ClosePositionInfo, ClaimPositionInfo} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import {ChromaticRouter} from "@chromatic-protocol/contracts/periphery/ChromaticRouter.sol";
import {VerifyCallback} from "@chromatic-protocol/contracts/periphery/base/VerifyCallback.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @title MockChromaticAccount
 * @dev This contract manages user accounts and positions.
 */
contract MockChromaticAccountV3 is IChromaticAccount, VerifyCallback {
    using EnumerableSet for EnumerableSet.UintSet;

    address private owner;
    address private router;
    bool isInitialized;
    uint256 callNumber;

    mapping(address => EnumerableSet.UintSet) private positionIds;

    /**
     * @dev Throws an error indicating that the caller is not the chromatic router contract.
     */
    error NotRouter();

    /**
     * @dev Throws an error indicating that the caller is not the owner of this account contract.
     */
    error NotOwner();

    /**
     * @dev Throws an error indicating that the account is already initialized, and calling the initialization function again is not allowed.
     */
    error AlreadyInitialized();

    /**
     * @dev Throws an error indicating that the account does not have sufficient balance to perform a particular operation, such as withdrawing an amount of tokens.
     */
    error NotEnoughBalance();

    /**
     * @dev Throws an error indicating that the caller is not the owner of this account contractthat the caller is not the owner of this account contract.
     */
    error NotExistPosition();

    /**
     * @dev Modifier that allows only the router to call a function.
     *      Throws an `NotRouter` error if the caller is not the chromatic router contract.
     */
    modifier onlyRouter() {
        if (msg.sender != router) revert NotRouter();
        _;
    }

    /**
     * @dev Modifier that allows only the owner to call a function.
     *      Throws an `NotOwner` error if the caller is not the owner of this account contract.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /**
     * @notice Initializes the account with the specified owner, router, and market factory addresses.
     * @dev Throws an `AlreadyInitialized` error if the account has already been initialized.
     * @param _owner The address of the account owner.
     * @param _router The address of the router contract.
     * @param _marketFactory The address of the market factory contract.
     */
    function initialize(address _owner, address _router, address _marketFactory) external {
        if (isInitialized) revert AlreadyInitialized();
        require(_owner != address(0));
        require(_router != address(0));
        require(_marketFactory != address(0));
        owner = _owner;
        router = _router;
        isInitialized = true;
        marketFactory = _marketFactory;
    }

    /**
     * @inheritdoc IChromaticAccount
     */
    function balance(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @inheritdoc IChromaticAccount
     * @dev This function can only be called by owner.
     *      Throws a `NotEnoughBalance` error if the account does not have enough balance of the specified token.
     */
    function withdraw(address token, uint256 amount) external onlyOwner {
        if (balance(token) < amount) revert NotEnoughBalance();
        SafeERC20.safeTransfer(IERC20(token), owner, amount);
    }

    function addPositionId(address market, uint256 positionId) internal {
        //slither-disable-next-line unused-return
        positionIds[market].add(positionId);
    }

    function removePositionId(address market, uint256 positionId) internal {
        //slither-disable-next-line unused-return
        positionIds[market].remove(positionId);
    }

    /**
     * @inheritdoc IChromaticAccount
     */
    function hasPositionId(address market, uint256 id) public view returns (bool) {
        return positionIds[market].contains(id);
    }

    /**
     * @inheritdoc IChromaticAccount
     */
    function getPositionIds(address market) external view returns (uint256[] memory) {
        return positionIds[market].values();
    }

    /**
     * @inheritdoc IChromaticAccount
     * @dev This function can only be called by the chromatic router contract.
     */
    function openPosition(
        address marketAddress,
        int256 qty,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee
    ) external onlyOwner returns (OpenPositionInfo memory position) {
        position = IChromaticMarket(marketAddress).openPosition(
            qty,
            takerMargin,
            makerMargin,
            maxAllowableTradingFee,
            bytes("")
        );
        addPositionId(marketAddress, position.id);
        //slither-disable-next-line reentrancy-events
        emit OpenPosition(
            marketAddress,
            position.id,
            position.openVersion,
            position.qty,
            position.openTimestamp,
            position.takerMargin,
            position.makerMargin,
            position.tradingFee
        );
    }

    /**
     * @inheritdoc IChromaticAccount
     * @dev This function can only be called by the chromatic router contract.
     *      Throws a `NotExistPosition` error if the position does not exist.
     */
    function closePosition(address marketAddress, uint256 positionId) external override onlyOwner {
        if (!hasPositionId(marketAddress, positionId)) revert NotExistPosition();

        ClosePositionInfo memory position = IChromaticMarket(marketAddress).closePosition(
            positionId
        );
        //slither-disable-next-line reentrancy-events
        emit ClosePosition(
            marketAddress,
            position.id,
            position.closeVersion,
            position.closeTimestamp
        );
    }

    /**
     * @inheritdoc IChromaticAccount
     * @dev This function can only be called by the chromatic router contract.
     *      Throws a `NotExistPosition` error if the position does not exist.
     */
    function claimPosition(address marketAddress, uint256 positionId) external override onlyOwner {
        if (!hasPositionId(marketAddress, positionId)) revert NotExistPosition();

        IChromaticMarket(marketAddress).claimPosition(positionId, address(this), bytes(""));
    }

    /**
     * @inheritdoc IChromaticTradeCallback
     * @dev Transfers the required margin from the account to the specified vault.
     *      Throws a `NotEnoughBalance` error if the account does not have enough balance of the settlement token.
     */
    function openPositionCallback(
        address settlementToken,
        address vault,
        uint256 marginRequired,
        bytes calldata /* data */
    ) external override verifyCallback {
        if (balance(settlementToken) < marginRequired) revert NotEnoughBalance();

        SafeERC20.safeTransfer(IERC20(settlementToken), vault, marginRequired);
    }

    /**
     * @inheritdoc IChromaticTradeCallback
     */
    function claimPositionCallback(
        Position memory position,
        ClaimPositionInfo memory claimInfo,
        bytes calldata /* data */
    ) external override verifyCallback {
        removePositionId(msg.sender, position.id);
        address marketAddress = msg.sender;
        emit ClaimPosition(
            marketAddress,
            claimInfo.id,
            claimInfo.entryPrice,
            claimInfo.exitPrice,
            claimInfo.realizedPnl,
            claimInfo.interest,
            claimInfo.cause
        );
    }

    function addLiquidity(address _marketAddress, uint256 amount, int16 feeRate) public {
        IChromaticMarket(_marketAddress).addLiquidity(
            address(this),
            feeRate,
            abi.encode(ChromaticRouter.AddLiquidityCallbackData({provider: msg.sender, amount: amount}))
        );
    }

    function addLiquidityCallback(
        address settlementToken,
        address vault,
        bytes calldata data
    ) external verifyCallback {
        ChromaticRouter.AddLiquidityCallbackData memory callbackData = abi.decode(data, (ChromaticRouter.AddLiquidityCallbackData));
        IERC20(settlementToken).approve(address(msg.sender), type(uint256).max);
        SafeERC20.safeTransfer(
            IERC20(settlementToken),
            vault,
            callbackData.amount
        );
    }

    function removeLiquidityBatch(
        address market,
        address recipient,
        int16[] calldata feeRates,
        uint256[] calldata clbTokenAmounts
    ) external returns (LpReceipt[] memory lpReceipts) {
        require(feeRates.length == clbTokenAmounts.length, "TradeRouter: invalid arguments");

        // address provider = msg.sender; // save gas : MSTORE,MLOAD - 3, CALLER(msg.sender) - 2
        lpReceipts = IChromaticMarket(market).removeLiquidityBatch(
            recipient,
            feeRates,
            clbTokenAmounts,
            abi.encode(
                ChromaticRouter.RemoveLiquidityBatchCallbackData({
                    provider: msg.sender,
                    clbTokenAmounts: clbTokenAmounts
                })
            )
        );
    }

    function removeLiquidityBatchCallback(
        address clbToken,
        uint256[] calldata clbTokenIds,
        bytes calldata data
    ) external verifyCallback {
        if(callNumber == 0){
            ChromaticRouter.RemoveLiquidityBatchCallbackData memory callbackData = abi.decode(
                data,
                (ChromaticRouter.RemoveLiquidityBatchCallbackData)
            );
            // IERC1155(clbToken).setApprovalForAll(address(this), true);
            IERC1155(clbToken).safeTransferFrom(
                address(this),
                msg.sender, // market
                clbTokenIds[0],
                callbackData.clbTokenAmounts[0],
                bytes("")
            );
        }
        callNumber += 1;
    }

    function onERC1155Received(
        address /* operator */,
        address /* from */,
        uint256 /* id */,
        uint256 /* value */,
        bytes calldata /* data */
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address /* operator */,
        address /* from */,
        uint256[] calldata /* ids */,
        uint256[] calldata /* values */,
        bytes calldata /* data */
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
        return
            interfaceID == this.onERC1155Received.selector ^ this.onERC1155BatchReceived.selector; // IERC1155Receiver
    }
}
