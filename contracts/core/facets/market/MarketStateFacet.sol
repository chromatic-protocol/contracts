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
    function feeProtocol() external view returns (uint8 _feeProtocol) {
        _feeProtocol = MarketStorageLib.marketStorage().feeProtocol;
    }

    /**
     * @inheritdoc IMarketState
     */
    function setFeeProtocol(uint8 _feeProtocol) external override onlyDao {
        require(_feeProtocol == 0 || (_feeProtocol >= 4 && _feeProtocol <= 10));

        MarketStorage storage ps = MarketStorageLib.marketStorage();

        uint8 feeProtocolOld = ps.feeProtocol;
        ps.feeProtocol = _feeProtocol;

        emit SetFeeProtocol(feeProtocolOld, _feeProtocol);
    }
}
