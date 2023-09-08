// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {IChromaticLP} from "@chromatic-protocol/contracts/lp/interfaces/IChromaticLP.sol";
import {ChromaticLPBase} from "@chromatic-protocol/contracts/lp/ChromaticLPBase.sol";
import {ChromaticLPLogic} from "@chromatic-protocol/contracts/lp/ChromaticLPLogic.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "@chromatic-protocol/contracts/lp/libraries/ChromaticLPReceipt.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";

uint16 constant BPS = 10000;

contract ChromaticLP is ChromaticLPBase, Proxy, IChromaticLP {
    address public immutable CHROMATIC_LP_LOGIC;

    constructor(ChromaticLPLogic lpLogic, Config memory config,
        int16[] memory feeRates,
        uint16[] memory distributionRates,
        AutomateParam memory automateParam) ChromaticLPBase(automateParam) {
        CHROMATIC_LP_LOGIC = address(lpLogic);
        _initialize(config, feeRates, distributionRates);
    }

    /**
     * @dev This is the address to which proxy functions are delegated to
     */
    function _implementation() internal view virtual override returns (address) {
        return CHROMATIC_LP_LOGIC;
    }

    function totalSupply() external view override returns (uint256) {}

    function balanceOf(address account) external view override returns (uint256) {}

    function transfer(address to, uint256 amount) external override returns (bool) {}

    function allowance(address owner, address spender) external view override returns (uint256) {}

    function approve(address spender, uint256 amount) external override returns (bool) {}

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool) {}

    function supportsInterface(bytes4 interfaceId) external view override returns (bool) {}

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {}

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {}

    function market() external view override returns (address) {}

    function settlementToken() external view override returns (address) {}

    function lpToken() external view override returns (address) {}

    function addLiquidity(
        uint256 amount,
        address recipient
    ) external override returns (ChromaticLPReceipt memory) {}

    function removeLiquidity(
        uint256 lpTokenAmount,
        address recipient
    ) external override returns (ChromaticLPReceipt memory) {}

    function settle(uint256 receiptId) external override returns (bool) {}

    function getReceiptIdsOf(address owner) external view override returns (uint256[] memory) {}

    function getReceipt(uint256 id) external view override returns (ChromaticLPReceipt memory) {}

    function resolveSettle(uint256 receiptId) external view override returns (bool, bytes memory) {}

    function resolveRebalance() external view override returns (bool, bytes memory) {}
}
