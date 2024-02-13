// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {BaseSetup} from "../BaseSetup.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {FEE_RATES_LENGTH} from "@chromatic-protocol/contracts/core/libraries/Constants.sol";
import "forge-std/console.sol";

contract GasUsage is BaseSetup, IERC1155Receiver {
    function setUp() public override {
        super.setUp();
        ctst.approve(address(router), type(uint256).max);
        clbToken.setApprovalForAll(address(router), true);
    }

    function test_addLiquidity() public {
        router.addLiquidity(address(market), 1, 10 ether, address(this));
    }

    function test_LiquidtyBatch() public {
        (
            int16[] memory feeRates,
            uint256[] memory amounts,
            address[] memory accounts
        ) = _liquidityBatchArgs();

        oracleProvider.increaseVersion(1 ether);
        router.addLiquidityBatch(address(market), address(this), feeRates, amounts);

        uint256[] memory receiptIds = router.getLpReceiptIds(address(market), address(this));

        oracleProvider.increaseVersion(1 ether);
        router.claimLiquidityBatch(address(market), receiptIds);

        oracleProvider.increaseVersion(1 ether);
        router.removeLiquidityBatch(
            address(market),
            address(this),
            feeRates,
            clbToken.balanceOfBatch(accounts, CLBTokenLib.tokenIds())
        );

        receiptIds = router.getLpReceiptIds(address(market), address(this));

        oracleProvider.increaseVersion(1 ether);
        router.withdrawLiquidityBatch(address(market), receiptIds);
    }

    function _liquidityBatchArgs()
        private
        view
        returns (int16[] memory feeRates, uint256[] memory amounts, address[] memory accounts)
    {
        feeRates = new int16[](FEE_RATES_LENGTH * 2);
        amounts = new uint256[](FEE_RATES_LENGTH * 2);
        accounts = new address[](FEE_RATES_LENGTH * 2);

        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates = CLBTokenLib.tradingFeeRates();
        for (uint i; i < FEE_RATES_LENGTH; i++) {
            feeRates[i] = int16(_tradingFeeRates[i]);
            amounts[i] = 1 ether;
            accounts[i] = address(this);
            feeRates[i + FEE_RATES_LENGTH] = -int16(_tradingFeeRates[i]);
            amounts[i + FEE_RATES_LENGTH] = 1 ether;
            accounts[i + FEE_RATES_LENGTH] = address(this);
        }
    }

    function onERC1155Received(
        address /* operator */,
        address /* from */,
        uint256 /* id */,
        uint256 /* value */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address /* operator */,
        address /* from */,
        uint256[] calldata /* ids */,
        uint256[] calldata /* values */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || // ERC165
            interfaceID == this.onERC1155Received.selector ^ this.onERC1155BatchReceived.selector; // IERC1155Receiver
    }
}
