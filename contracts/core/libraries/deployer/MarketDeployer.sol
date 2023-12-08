// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {IDiamondCut} from "@chromatic-protocol/contracts/core/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@chromatic-protocol/contracts/core/interfaces/IDiamondLoupe.sol";
import {IMarketState} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketState.sol";
import {IMarketLiquidity} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidity.sol";
import {IMarketLens} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLens.sol";
import {IMarketTrade} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketTrade.sol";
import {IMarketLiquidate} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidate.sol";
import {IMarketSettle} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketSettle.sol";
import {ChromaticMarket} from "@chromatic-protocol/contracts/core/ChromaticMarket.sol";

/**
 * @dev Storage struct for deploying a ChromaticMarket contract
 */
struct MarketDeployer {
    Parameters parameters;
}

/**
 * @dev Struct for storing deployment parameters
 */
struct Parameters {
    address oracleProvider;
    address settlementToken;
}

/**
 * @title MarketDeployerLib
 * @notice Library for deploying a ChromaticMarket contract
 */
library MarketDeployerLib {
    /**
     * @notice Deploys a ChromaticMarket contract
     * @param self The MarketDeployer storage
     * @param oracleProvider The address of the oracle provider
     * @param settlementToken The address of the settlement token
     * @param marketDiamondCutFacet The market diamond cut facet address.
     * @param marketLoupeFacet The market loupe facet address.
     * @param marketStateFacet The market state facet address.
     * @param marketLiquidityFacet The market liquidity facet address.
     * @param marketLensFacet The market liquidity lens facet address.
     * @param marketTradeFacet The market trade facet address.
     * @param marketLiquidateFacet The market liquidate facet address.
     * @param marketSettleFacet The market settle facet address.
     * @return market The address of the deployed ChromaticMarket contract
     */
    function deploy(
        MarketDeployer storage self,
        address oracleProvider,
        address settlementToken,
        address marketDiamondCutFacet,
        address marketLoupeFacet,
        address marketStateFacet,
        address marketLiquidityFacet,
        address marketLensFacet,
        address marketTradeFacet,
        address marketLiquidateFacet,
        address marketSettleFacet
    ) external returns (address market) {
        self.parameters = Parameters({
            oracleProvider: oracleProvider,
            settlementToken: settlementToken
        });
        market = address(
            new ChromaticMarket{salt: keccak256(abi.encode(oracleProvider, settlementToken))}(
                marketDiamondCutFacet
            )
        );
        delete self.parameters;

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](7);
        cut[0] = _marketLoupeFacetCut(marketLoupeFacet);
        cut[1] = _marketStateFacetCut(marketStateFacet);
        cut[2] = _marketLiquidityFacetCut(marketLiquidityFacet);
        cut[3] = _marketLensFacetCut(marketLensFacet);
        cut[4] = _marketTradeFacetCut(marketTradeFacet);
        cut[5] = _marketLiquidateFacetCut(marketLiquidateFacet);
        cut[6] = _marketSettleFacetCut(marketSettleFacet);
        IDiamondCut(market).diamondCut(cut, address(0), "");
    }

    function _marketLoupeFacetCut(
        address marketLoupeFacet
    ) private pure returns (IDiamondCut.FacetCut memory cut) {
        bytes4[] memory functionSelectors = new bytes4[](4);
        functionSelectors[0] = IDiamondLoupe.facets.selector;
        functionSelectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        functionSelectors[2] = IDiamondLoupe.facetAddresses.selector;
        functionSelectors[3] = IDiamondLoupe.facetAddress.selector;

        cut = IDiamondCut.FacetCut({
            facetAddress: marketLoupeFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
    }

    function _marketStateFacetCut(
        address marketStateFacet
    ) private pure returns (IDiamondCut.FacetCut memory cut) {
        bytes4[] memory functionSelectors = new bytes4[](8);
        functionSelectors[0] = IMarketState.factory.selector;
        functionSelectors[1] = IMarketState.settlementToken.selector;
        functionSelectors[2] = IMarketState.oracleProvider.selector;
        functionSelectors[3] = IMarketState.clbToken.selector;
        functionSelectors[4] = IMarketState.liquidator.selector;
        functionSelectors[5] = IMarketState.vault.selector;
        functionSelectors[6] = IMarketState.feeProtocol.selector;
        functionSelectors[7] = IMarketState.setFeeProtocol.selector;

        cut = IDiamondCut.FacetCut({
            facetAddress: marketStateFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
    }

    function _marketLiquidityFacetCut(
        address marketLiquidityFacet
    ) private pure returns (IDiamondCut.FacetCut memory cut) {
        bytes4[] memory functionSelectors = new bytes4[](12);
        functionSelectors[0] = IMarketLiquidity.addLiquidity.selector;
        functionSelectors[1] = IMarketLiquidity.addLiquidityBatch.selector;
        functionSelectors[2] = IMarketLiquidity.claimLiquidity.selector;
        functionSelectors[3] = IMarketLiquidity.claimLiquidityBatch.selector;
        functionSelectors[4] = IMarketLiquidity.removeLiquidity.selector;
        functionSelectors[5] = IMarketLiquidity.removeLiquidityBatch.selector;
        functionSelectors[6] = IMarketLiquidity.withdrawLiquidity.selector;
        functionSelectors[7] = IMarketLiquidity.withdrawLiquidityBatch.selector;
        functionSelectors[8] = IMarketLiquidity.distributeEarningToBins.selector;
        functionSelectors[9] = IERC1155Receiver.onERC1155Received.selector;
        functionSelectors[10] = IERC1155Receiver.onERC1155BatchReceived.selector;
        functionSelectors[11] = IERC165.supportsInterface.selector;

        cut = IDiamondCut.FacetCut({
            facetAddress: marketLiquidityFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
    }

    function _marketLensFacetCut(
        address marketLensFacet
    ) private pure returns (IDiamondCut.FacetCut memory cut) {
        bytes4[] memory functionSelectors = new bytes4[](16);
        functionSelectors[0] = IMarketLens.getBinLiquidity.selector;
        functionSelectors[1] = IMarketLens.getBinFreeLiquidity.selector;
        functionSelectors[2] = IMarketLens.getBinValues.selector;
        functionSelectors[3] = IMarketLens.getLpReceipt.selector;
        functionSelectors[4] = IMarketLens.getLpReceipts.selector;
        functionSelectors[5] = IMarketLens.pendingLiquidity.selector;
        functionSelectors[6] = IMarketLens.pendingLiquidityBatch.selector;
        functionSelectors[7] = IMarketLens.claimableLiquidity.selector;
        functionSelectors[8] = IMarketLens.claimableLiquidityBatch.selector;
        functionSelectors[9] = IMarketLens.liquidityBinStatuses.selector;
        functionSelectors[10] = IMarketLens.getPosition.selector;
        functionSelectors[11] = IMarketLens.getPositions.selector;
        functionSelectors[12] = IMarketLens.pendingPosition.selector;
        functionSelectors[13] = IMarketLens.pendingPositionBatch.selector;
        functionSelectors[14] = IMarketLens.closingPosition.selector;
        functionSelectors[15] = IMarketLens.closingPositionBatch.selector;

        cut = IDiamondCut.FacetCut({
            facetAddress: marketLensFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
    }

    function _marketTradeFacetCut(
        address marketTradeFacet
    ) private pure returns (IDiamondCut.FacetCut memory cut) {
        bytes4[] memory functionSelectors = new bytes4[](3);
        functionSelectors[0] = IMarketTrade.openPosition.selector;
        functionSelectors[1] = IMarketTrade.closePosition.selector;
        functionSelectors[2] = IMarketTrade.claimPosition.selector;

        cut = IDiamondCut.FacetCut({
            facetAddress: marketTradeFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
    }

    function _marketLiquidateFacetCut(
        address marketLiquidateFacet
    ) private pure returns (IDiamondCut.FacetCut memory cut) {
        bytes4[] memory functionSelectors = new bytes4[](4);
        functionSelectors[0] = IMarketLiquidate.checkLiquidation.selector;
        functionSelectors[1] = IMarketLiquidate.liquidate.selector;
        functionSelectors[2] = IMarketLiquidate.checkClaimPosition.selector;
        functionSelectors[3] = IMarketLiquidate.claimPosition.selector;

        cut = IDiamondCut.FacetCut({
            facetAddress: marketLiquidateFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
    }

    function _marketSettleFacetCut(
        address marketSettleFacet
    ) private pure returns (IDiamondCut.FacetCut memory cut) {
        bytes4[] memory functionSelectors = new bytes4[](2);
        functionSelectors[0] = IMarketSettle.settle.selector;
        functionSelectors[1] = IMarketSettle.settleAll.selector;

        cut = IDiamondCut.FacetCut({
            facetAddress: marketSettleFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
    }
}
