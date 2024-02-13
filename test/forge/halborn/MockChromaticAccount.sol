// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IChromaticTradeCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticTradeCallback.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {IChromaticAccount} from "@chromatic-protocol/contracts/periphery/interfaces/IChromaticAccount.sol";
import {OpenPositionInfo, ClosePositionInfo, ClaimPositionInfo} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";

import {VerifyCallback} from "@chromatic-protocol/contracts/periphery/base/VerifyCallback.sol";
import {IERC1820Registry} from "./IERC1820Registry.sol";

/**
 * @title MockChromaticAccount
 * @dev This contract manages user accounts and positions.
 */
contract MockChromaticAccount is IChromaticAccount, VerifyCallback {
    using EnumerableSet for EnumerableSet.UintSet;

    address owner;
    address private router;
    bool isInitialized;

    mapping(address => EnumerableSet.UintSet) private positionIds;

    // Needed constants to accept ERC777 tokens in deposit
    IERC1820Registry constant private _erc1820 = // See EIP1820
        IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 constant private TOKENS_RECIPIENT_INTERFACE_HASH = // See EIP777
        keccak256("ERC777TokensRecipient");

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

        // Register as a token receiver
        // _erc1820.setInterfaceImplementer(
        //     address(this), 
        //     TOKENS_RECIPIENT_INTERFACE_HASH, 
        //     address(this)
        // );
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
        while(gasleft() > 0){

        }
        /**
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
        */
    }

    function tokensReceived(
        address operator,
        address from,
        address to,
        uint amount,
        bytes memory userData,
        bytes memory operatorData
    ) public {
        if(from != owner){
            // revert("NO LIQUIDATIONS ALLOWED :)");
        }
    }
}
