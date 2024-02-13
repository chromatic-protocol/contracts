// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

import "./base/OracleProviderPullBasedBase.sol";
import "@pythnetwork/pyth-sdk-solidity/AbstractPyth.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {SignedSafeMath} from "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";
import {PythOffchainPrice} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2Automation1_1.sol";

// TODO mapping(bytes => uint256) => vaa : version
// 이미 업데이트 된 vaa는 업데이트 안하게
contract PythFeedOracle is OracleProviderPullBasedBase {
    using SignedMath for int256;
    using SignedSafeMath for int256;

    error PriceFeedNotExist();

    int256 private constant BASE = 1e18;

    /// @dev Pyth address (https://docs.pyth.network/documentation/pythnet-price-feeds/evm)
    AbstractPyth public immutable pyth;

    /// @dev The id of pyth price feed (https://pyth.network/developers/price-feed-ids#pyth-evm-mainnet)
    bytes32 public immutable priceFeedId;

    /// @dev The description of the Oracle Provider('ETH/USD', 'BTC/USD'...)
    string private _description;

    /// @dev Last version seen when `sync` was called
    uint256 private lastSyncedVersion;

    /// @dev Last publishTime seen when `sync` was called
    uint256 private lastSyncedPublishTime;

    /// @dev Mapping of version to OracleVersion
    mapping(uint256 => OracleVersion) private oracleVersions;

    // lastSyncedVersion external TODO

    /**
     * @notice Initializes the contract state
     * @param pyth_ Pyth address (https://docs.pyth.network/documentation/pythnet-price-feeds/evm)
     * @param priceFeedId_ The id of pyth price feed (https://pyth.network/developers/price-feed-ids#pyth-evm-mainnet)
     * @param description_ The description of the Oracle Provider('ETH/USD', 'BTC/USD'...)
     */
    constructor(AbstractPyth pyth_, bytes32 priceFeedId_, string memory description_) {
        pyth = pyth_;
        if (!pyth.priceFeedExists(priceFeedId_)) {
            revert PriceFeedNotExist();
        }
        priceFeedId = priceFeedId_;
        _description = description_;
        sync();
    }

    /**
     * @inheritdoc IOracleProvider
     */
    function sync() public returns (OracleVersion memory) {
        PythStructs.Price memory latestPrice = pyth.getPriceUnsafe(priceFeedId);
        if (lastSyncedPublishTime != latestPrice.publishTime) {
            lastSyncedVersion++;
            lastSyncedPublishTime = latestPrice.publishTime;

            int256 pythDecimal = int256(10 ** int256(latestPrice.expo).abs());

            oracleVersions[lastSyncedVersion] = OracleVersion({
                version: lastSyncedVersion,
                timestamp: latestPrice.publishTime,
                price: latestPrice.expo > 0
                    ? int256(latestPrice.price).mul(BASE).mul(pythDecimal)
                    : int256(latestPrice.price).mul(BASE).div(pythDecimal)
            });
        }
        return oracleVersions[lastSyncedVersion];
    }

    /**
     * @inheritdoc IOracleProvider
     */
    function currentVersion() public view returns (OracleVersion memory oracleVersion) {
        PythStructs.Price memory latestPrice = pyth.getPriceUnsafe(priceFeedId);
        oracleVersion = oracleVersions[lastSyncedVersion];
        if (latestPrice.publishTime > oracleVersion.timestamp) {
            int256 pythDecimal = int256(10 ** int256(latestPrice.expo).abs());
            oracleVersion = OracleVersion({
                version: lastSyncedVersion + 1,
                timestamp: latestPrice.publishTime,
                price: latestPrice.expo > 0
                    ? int256(latestPrice.price).mul(BASE).mul(pythDecimal)
                    : int256(latestPrice.price).mul(BASE).div(pythDecimal)
            });
        }
    }

    /**
     * @inheritdoc IOracleProvider
     */
    function atVersion(uint256 version) public view returns (OracleVersion memory oracleVersion) {
        return oracleVersions[version];
    }

    /**
     * @inheritdoc IOracleProvider
     */
    function description() external view override returns (string memory) {
        return _description;
    }

    /**
     * @inheritdoc IOracleProvider
     */
    function oracleProviderName() external pure override returns (string memory) {
        return "pyth";
    }

    function extraModule() external pure override returns (ExtraModule) {
        return ExtraModule.Pyth;
    }

    function extraParam() external view override returns (bytes memory) {
        return abi.encodePacked(priceFeedId);
    }

    function updatePrice(bytes calldata offchainData) external payable override {
        // TODO validation : id, price, timestamp...
        bytes[] memory updateDatas = new bytes[](1);
        PythOffchainPrice memory offChainPrice = decodeOffchainData(offchainData);
        updateDatas[0] = offChainPrice.vaa;
        pyth.updatePriceFeeds{value: msg.value}(updateDatas);
        PythStructs.Price memory onchainPrice = pyth.getPrice(priceFeedId);
        // TODO validate and update internal struct
    }

    function getUpdateFee(bytes calldata offchainData) external view override returns (uint256) {
        bytes[] memory updateDatas = new bytes[](1);
        updateDatas[0] = decodeOffchainData(offchainData).vaa;
        return pyth.getUpdateFee(updateDatas);
    }

    function decodeOffchainData(
        bytes calldata offchainData
    ) internal pure returns (PythOffchainPrice memory) {
        return abi.decode(offchainData, (PythOffchainPrice));
    }
}
