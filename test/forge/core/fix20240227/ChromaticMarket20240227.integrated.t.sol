// forge test --fork-url "https://arb-mainnet.g.alchemy.com/v2/<ALCHEMY_KEY>" --match-contract 'ChromaitcMarket20240227Test'

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import "@chromatic-protocol/contracts/core/facets/market/MarketAddLiquidityFacet.sol";
import "@chromatic-protocol/contracts/core/facets/market/MarketRemoveLiquidityFacet.sol";
import "@chromatic-protocol/contracts/core/interfaces/IDiamondCut.sol";
import "@chromatic-protocol/contracts/core/interfaces/IDiamondLoupe.sol";
import "@chromatic-protocol/contracts/core/interfaces/market/IMarketRemoveLiquidity.sol";
import "forge-std/StdError.sol";
import "forge-std/console.sol";

enum ChromaticLPAction {
    ADD_LIQUIDITY,
    REMOVE_LIQUIDITY
}

struct ChromaticLPReceipt {
    uint256 id;
    address provider;
    address recipient;
    uint256 oracleVersion;
    uint256 amount;
    uint256 pendingLiquidity;
    ChromaticLPAction action;
    bool needSettle;
}

interface IChromaticLP {
    function addLiquidity(
        uint256 amount,
        address recipient
    ) external returns (ChromaticLPReceipt memory);

    function settle(uint256 receiptId) external;

    function getReceipt(uint256 id) external view returns (ChromaticLPReceipt memory);

    function setSuspendMode(uint8 mode) external;
}

contract ChromaitcMarket20240227Test is Test {
    IERC20 constant USDT = IERC20(address(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9));
    address constant MARKET_ADDRESS = address(0x23d0bF4316F5c768Be8983f71f5C05717E13E5d5);
    address constant LP_ADDRESS = address(0x9706DE4B4Bb1027ce059344Cd42Bb57E079f64c7);
    address constant DAO_ADDRESS = address(0x36608c490fE6616C6D35782244A055c3F395811E);

    uint256 constant LP_RECEIPT_ID = 4;

    IChromaticLP lp;
    IDiamondCut market;
    IDiamondLoupe loupe;

    function setUp() public virtual {
        vm.rollFork(184996764);

        lp = IChromaticLP(LP_ADDRESS);
        market = IDiamondCut(MARKET_ADDRESS);
        loupe = IDiamondLoupe(MARKET_ADDRESS);

        vm.startPrank(DAO_ADDRESS);
        lp.setSuspendMode(0);
        vm.stopPrank();

        deal(address(USDT), address(this), 1000_000_000);
    }

    function testAddLiquidity() public virtual {
        USDT.approve(address(lp), 1000_000_000);

        vm.expectRevert(bytes("IOV"));
        lp.addLiquidity(1000_000_000, address(this));

        vm.startPrank(DAO_ADDRESS);

        MarketAddLiquidityFacet fixedFacet = new MarketAddLiquidityFacet();
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = _marketAddLiquidityFacetCut(address(fixedFacet));

        market.diamondCut(cut, address(0), "");

        vm.stopPrank();

        lp.addLiquidity(1000_000_000, address(this));
    }

    function testRemoveLiquidity() public virtual {
        vm.expectRevert(stdError.divisionError);
        lp.settle(LP_RECEIPT_ID);

        vm.startPrank(DAO_ADDRESS);

        MarketRemoveLiquidityFacet fixedFacet = new MarketRemoveLiquidityFacet();
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = _marketRemoveLiquidityFacetCut(address(fixedFacet));

        market.diamondCut(cut, address(0), "");

        vm.stopPrank();

        ChromaticLPReceipt memory receipt = lp.getReceipt(LP_RECEIPT_ID);
        uint256 balanceBefore = USDT.balanceOf(receipt.recipient);

        lp.settle(LP_RECEIPT_ID);

        uint256 withdrawn = USDT.balanceOf(receipt.recipient) - balanceBefore;
        console.log("withdrawn: %d", withdrawn);

        assertGt(withdrawn, 0);
    }

    function _marketAddLiquidityFacetCut(
        address marketAddLiquidityFacet
    ) private pure returns (IDiamondCut.FacetCut memory cut) {
        bytes4[] memory functionSelectors = new bytes4[](5);
        functionSelectors[0] = IMarketAddLiquidity.addLiquidity.selector;
        functionSelectors[1] = IMarketAddLiquidity.addLiquidityBatch.selector;
        functionSelectors[2] = IMarketAddLiquidity.claimLiquidity.selector;
        functionSelectors[3] = IMarketAddLiquidity.claimLiquidityBatch.selector;
        functionSelectors[4] = IMarketAddLiquidity.distributeEarningToBins.selector;

        cut = IDiamondCut.FacetCut({
            facetAddress: marketAddLiquidityFacet,
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: functionSelectors
        });
    }

    function _marketRemoveLiquidityFacetCut(
        address marketRemoveLiquidityFacet
    ) private pure returns (IDiamondCut.FacetCut memory cut) {
        bytes4[] memory functionSelectors = new bytes4[](7);
        functionSelectors[0] = IMarketRemoveLiquidity.removeLiquidity.selector;
        functionSelectors[1] = IMarketRemoveLiquidity.removeLiquidityBatch.selector;
        functionSelectors[2] = IMarketRemoveLiquidity.withdrawLiquidity.selector;
        functionSelectors[3] = IMarketRemoveLiquidity.withdrawLiquidityBatch.selector;
        functionSelectors[4] = IERC1155Receiver.onERC1155Received.selector;
        functionSelectors[5] = IERC1155Receiver.onERC1155BatchReceived.selector;
        functionSelectors[6] = IERC165.supportsInterface.selector;

        cut = IDiamondCut.FacetCut({
            facetAddress: marketRemoveLiquidityFacet,
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: functionSelectors
        });
    }
}
