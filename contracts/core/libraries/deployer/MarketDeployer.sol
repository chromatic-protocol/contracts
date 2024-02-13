// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {IDiamondCut} from "@chromatic-protocol/contracts/core/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@chromatic-protocol/contracts/core/interfaces/IDiamondLoupe.sol";
import {IMarketState} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketState.sol";
import {IMarketAddLiquidity} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketAddLiquidity.sol";
import {IMarketRemoveLiquidity} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketRemoveLiquidity.sol";
import {IMarketLens} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLens.sol";
import {IMarketTradeOpenPosition} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketTradeOpenPosition.sol";
import {IMarketTradeClosePosition} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketTradeClosePosition.sol";
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
    uint16 protocolFeeRate;
}

/**
 * @title the arguments for deploy
 * @param oracleProvider The address of the oracle provider
 * @param settlementToken The address of the settlement token
 * @param marketDiamondCutFacet The market diamond cut facet address.
 * @param marketLoupeFacet The market loupe facet address.
 * @param marketStateFacet The market state facet address.
 * @param marketAddLiquidityFacet The market liquidity facet address for adding and claiming.
 * @param marketRemoveLiquidityFacet The market liquidity facet address for removing and withdrawing.
 * @param marketLensFacet The market liquidity lens facet address.
 * @param marketTradeOpenPositionFacet The market trade facet address for opending positions.
 * @param marketTradeClosePositionFacet The market trade facet address for closing and claiming positions.
 * @param marketLiquidateFacet The market liquidate facet address.
 * @param marketSettleFacet The market settle facet address.
 * @param protocolFeeRate The protocol fee rate for the market.
 */
struct DeployArgs {
    address oracleProvider;
    address settlementToken;
    address marketDiamondCutFacet;
    address marketLoupeFacet;
    address marketStateFacet;
    address marketAddLiquidityFacet;
    address marketRemoveLiquidityFacet;
    address marketLensFacet;
    address marketTradeOpenPositionFacet;
    address marketTradeClosePositionFacet;
    address marketLiquidateFacet;
    address marketSettleFacet;
    uint16 protocolFeeRate;
}

/**
 * @title MarketDeployerLib
 * @notice Library for deploying a ChromaticMarket contract
 */
library MarketDeployerLib {
    /**
     * @notice Deploys a ChromaticMarket contract
     * @param self The MarketDeployer storage
     * @param args The arguments for deploy
     * @return market The address of the deployed ChromaticMarket contract
     */
    function deploy(
        MarketDeployer storage self,
        DeployArgs memory args
    ) external returns (address market) {
        self.parameters = Parameters({
            oracleProvider: args.oracleProvider,
            settlementToken: args.settlementToken,
            protocolFeeRate: args.protocolFeeRate
        });
        market = address(
            new ChromaticMarket{
                salt: keccak256(abi.encode(args.oracleProvider, args.settlementToken))
            }(args.marketDiamondCutFacet)
        );
        delete self.parameters;

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](9);
        cut[0] = _marketLoupeFacetCut(args.marketLoupeFacet);
        cut[1] = _marketStateFacetCut(args.marketStateFacet);
        cut[2] = _marketAddLiquidityFacetCut(args.marketAddLiquidityFacet);
        cut[3] = _marketRemoveLiquidityFacetCut(args.marketRemoveLiquidityFacet);
        cut[4] = _marketLensFacetCut(args.marketLensFacet);
        cut[5] = _marketTradeOpenPositionFacetCut(args.marketTradeOpenPositionFacet);
        cut[6] = _marketTradeClosePositionFacetCut(args.marketTradeClosePositionFacet);
        cut[7] = _marketLiquidateFacetCut(args.marketLiquidateFacet);
        cut[8] = _marketSettleFacetCut(args.marketSettleFacet);
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
        bytes4[] memory functionSelectors = new bytes4[](13);
        functionSelectors[0] = IMarketState.factory.selector;
        functionSelectors[1] = IMarketState.settlementToken.selector;
        functionSelectors[2] = IMarketState.oracleProvider.selector;
        functionSelectors[3] = IMarketState.clbToken.selector;
        functionSelectors[4] = IMarketState.vault.selector;
        functionSelectors[5] = IMarketState.protocolFeeRate.selector;
        functionSelectors[6] = IMarketState.updateProtocolFeeRate.selector;
        functionSelectors[7] = IMarketState.positionMode.selector;
        functionSelectors[8] = IMarketState.updatePositionMode.selector;
        functionSelectors[9] = IMarketState.liquidityMode.selector;
        functionSelectors[10] = IMarketState.updateLiquidityMode.selector;
        functionSelectors[11] = IMarketState.displayMode.selector;
        functionSelectors[12] = IMarketState.updateDisplayMode.selector;

        cut = IDiamondCut.FacetCut({
            facetAddress: marketStateFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
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
            action: IDiamondCut.FacetCutAction.Add,
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

    function _marketTradeOpenPositionFacetCut(
        address marketTradeFacet
    ) private pure returns (IDiamondCut.FacetCut memory cut) {
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IMarketTradeOpenPosition.openPosition.selector;

        cut = IDiamondCut.FacetCut({
            facetAddress: marketTradeFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
    }

    function _marketTradeClosePositionFacetCut(
        address marketTradeFacet
    ) private pure returns (IDiamondCut.FacetCut memory cut) {
        bytes4[] memory functionSelectors = new bytes4[](2);
        functionSelectors[0] = IMarketTradeClosePosition.closePosition.selector;
        functionSelectors[1] = IMarketTradeClosePosition.claimPosition.selector;

        cut = IDiamondCut.FacetCut({
            facetAddress: marketTradeFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
    }

    function _marketLiquidateFacetCut(
        address marketLiquidateFacet
    ) private pure returns (IDiamondCut.FacetCut memory cut) {
        bytes4[] memory functionSelectors = new bytes4[](5);
        functionSelectors[0] = IMarketLiquidate.checkLiquidation.selector;
        functionSelectors[1] = IMarketLiquidate.checkLiquidationWithOracleVersion.selector;
        functionSelectors[2] = IMarketLiquidate.liquidate.selector;
        functionSelectors[3] = IMarketLiquidate.checkClaimPosition.selector;
        functionSelectors[4] = IMarketLiquidate.claimPosition.selector;

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
