// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticMarket} from "@chromatic/core/interfaces/IChromaticMarket.sol";
import {IChromaticTradeCallback} from "@chromatic/core/interfaces/callback/IChromaticTradeCallback.sol";
import {Position} from "@chromatic/core/libraries/Position.sol";
import {IChromaticAccount} from "@chromatic/periphery/interfaces/IChromaticAccount.sol";
import {VerifyCallback} from "@chromatic/periphery/base/VerifyCallback.sol";

/**
 * @title ChromaticAccount
 * @dev This contract manages user accounts and positions.
 */
contract ChromaticAccount is IChromaticAccount, VerifyCallback {
    using EnumerableSet for EnumerableSet.UintSet;

    address owner;
    address private router;
    bool isInitialized;

    mapping(address => EnumerableSet.UintSet) private positionIds;

    error NotRouter();
    error NotOwner();
    error AlreadyInitialized();
    error NotEnoughBalance();
    error NotExistPosition();

    /**
     * @dev Modifier that allows only the router to call a function.
     */
    modifier onlyRouter() {
        if (msg.sender != router) revert NotRouter();
        _;
    }

    /**
     * @dev Modifier that allows only the owner to call a function.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /**
     * @notice Initializes the account with the specified owner, router, and market factory addresses.
     * @param _owner The address of the account owner.
     * @param _router The address of the router contract.
     * @param _marketFactory The address of the market factory contract.
     */
    function initialize(address _owner, address _router, address _marketFactory) external {
        if (isInitialized) revert AlreadyInitialized();
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
     */
    function withdraw(address token, uint256 amount) external onlyOwner {
        if (balance(token) < amount) revert NotEnoughBalance();
        SafeERC20.safeTransfer(IERC20(token), owner, amount);
    }

    function addPositionId(address market, uint256 positionId) internal {
        positionIds[market].add(positionId);
    }

    function removePositionId(address market, uint256 positionId) internal {
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
     */
    function openPosition(
        address marketAddress,
        int224 qty,
        uint32 leverage,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee
    ) external onlyRouter returns (Position memory position) {
        position = IChromaticMarket(marketAddress).openPosition(
            qty,
            leverage,
            takerMargin,
            makerMargin,
            maxAllowableTradingFee,
            bytes("")
        );
        addPositionId(marketAddress, position.id);
    }

    /**
     * @inheritdoc IChromaticAccount
     */
    function closePosition(address marketAddress, uint256 positionId) external override onlyRouter {
        if (!hasPositionId(marketAddress, positionId)) revert NotExistPosition();

        IChromaticMarket(marketAddress).closePosition(positionId);
    }

    /**
     * @inheritdoc IChromaticAccount
     */
    function claimPosition(address marketAddress, uint256 positionId) external override onlyRouter {
        if (!hasPositionId(marketAddress, positionId)) revert NotExistPosition();

        IChromaticMarket(marketAddress).claimPosition(positionId, address(this), bytes(""));
    }

    /**
     * @inheritdoc IChromaticTradeCallback
     */
    function openPositionCallback(
        address settlementToken,
        address vault,
        uint256 marginRequired,
        bytes calldata data
    ) external override verifyCallback {
        if (balance(settlementToken) < marginRequired) revert NotEnoughBalance();

        SafeERC20.safeTransfer(IERC20(settlementToken), vault, marginRequired);
    }

    /**
     * @inheritdoc IChromaticTradeCallback
     */
    function claimPositionCallback(
        uint256 positionId,
        bytes calldata data
    ) external override verifyCallback {
        removePositionId(msg.sender, positionId);
    }
}
