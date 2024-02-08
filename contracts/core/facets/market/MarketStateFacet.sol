// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";
import {IMarketState} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketState.sol";
import {MarketStorage, MarketStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {MarketFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketFacetBase.sol";

/**
 * @title MarketStateFacet
 */
contract MarketStateFacet is MarketFacetBase, IMarketState {
    /**
     * @inheritdoc IMarketState
     */
    function factory() external view returns (IChromaticMarketFactory _factory) {
        _factory = MarketStorageLib.marketStorage().factory;
    }

    /**
     * @inheritdoc IMarketState
     */
    function settlementToken() external view returns (IERC20Metadata _token) {
        _token = MarketStorageLib.marketStorage().settlementToken;
    }

    /**
     * @inheritdoc IMarketState
     */
    function oracleProvider() external view returns (IOracleProvider _provider) {
        _provider = MarketStorageLib.marketStorage().oracleProvider;
    }

    /**
     * @inheritdoc IMarketState
     */
    function clbToken() external view returns (ICLBToken _token) {
        _token = MarketStorageLib.marketStorage().clbToken;
    }

    /**
     * @inheritdoc IMarketState
     */
    function vault() external view returns (IChromaticVault _vault) {
        _vault = MarketStorageLib.marketStorage().vault;
    }

    /**
     * @inheritdoc IMarketState
     */
    function protocolFeeRate() external view returns (uint16 _protocolFeeRate) {
        _protocolFeeRate = MarketStorageLib.marketStorage().protocolFeeRate;
    }

    /**
     * @inheritdoc IMarketState
     */
    function setProtocolFeeRate(uint16 _protocolFeeRate) external override onlyDao {
        require(_protocolFeeRate <= 5000); // 50%

        MarketStorage storage ps = MarketStorageLib.marketStorage();

        uint16 protocolFeeRateOld = ps.protocolFeeRate;
        ps.protocolFeeRate = _protocolFeeRate;

        emit ProtocolFeeRateUpdated(protocolFeeRateOld, _protocolFeeRate);
    }
}
