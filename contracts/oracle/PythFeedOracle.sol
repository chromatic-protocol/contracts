// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {SignedSafeMath} from "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";
import {PythOffchainPrice, ExtraModule} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2Automation1_1.sol";
import {OracleProviderPullBasedBase, IOracleProvider, IOracleProviderPullBased} from "@chromatic-protocol/contracts/oracle/base/OracleProviderPullBasedBase.sol";
import {AbstractPyth, PythStructs} from "@pythnetwork/pyth-sdk-solidity/AbstractPyth.sol";

contract PythFeedOracle is OracleProviderPullBasedBase {
    using SignedMath for int256;
    using SignedSafeMath for int256;

    error PriceFeedNotExist();
    error WrongData();

    /// @dev Pyth address (https://docs.pyth.network/documentation/pythnet-price-feeds/evm)
    AbstractPyth public immutable pyth;

    /// @dev The id of pyth price feed (https://pyth.network/developers/price-feed-ids#pyth-evm-mainnet)
    bytes32 public immutable priceFeedId;

    /// @dev The description of the Oracle Provider('ETH/USD', 'BTC/USD'...)
    string private _description;

    /// @dev Last version index seen when `sync` was called
    uint256 private lastSyncedVersionIndex;

    /// @dev Mapping of version to OracleVersion
    mapping(uint256 => OracleVersion) private oracleVersions;

    /// @dev Mapping of updateData(vaa) to version index
    mapping(bytes32 => bool) private updatedVaa;

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
        PythStructs.Price memory price = pyth.getPriceUnsafe(priceFeedId);
        OracleVersion memory lastVersion = oracleVersions[lastSyncedVersionIndex];
        if (lastVersion.timestamp < price.publishTime) {
            ++lastSyncedVersionIndex;
            oracleVersions[lastSyncedVersionIndex] = pythPriceToOracleVersion(
                price,
                lastSyncedVersionIndex
            );
        }
        return oracleVersions[lastSyncedVersionIndex];
    }

    /**
     * @inheritdoc IOracleProvider
     */
    function currentVersion() public view returns (OracleVersion memory oracleVersion) {
        PythStructs.Price memory price = pyth.getPriceUnsafe(priceFeedId);
        oracleVersion = oracleVersions[lastSyncedVersionIndex];
        if (price.publishTime > oracleVersion.timestamp) {
            oracleVersion = pythPriceToOracleVersion(price, lastSyncedVersionIndex + 1);
        }
    }

    /**
     * @inheritdoc IOracleProviderPullBased
     */
    function lastSyncedVersion() external view returns (OracleVersion memory) {
        return oracleVersions[lastSyncedVersionIndex];
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

    /**
     * @inheritdoc IOracleProviderPullBased
     */
    function extraModule() external pure override returns (ExtraModule) {
        return ExtraModule.Pyth;
    }

    /**
     * @inheritdoc IOracleProviderPullBased
     */
    function extraParam() external view override returns (bytes memory) {
        return abi.encodePacked(priceFeedId);
    }

    /**
     * @inheritdoc IOracleProviderPullBased
     */
    function updatePrice(bytes calldata offchainData) external payable override {
        PythOffchainPrice memory offChainPrice = decodeOffchainData(offchainData);

        bytes32 vaa = keccak256(offChainPrice.vaa);
        if (updatedVaa[vaa]) {
            (bool success, ) = msg.sender.call{value: msg.value}("");
            require(success, "oracle update fee refund rejected");
            return;
        }

        bytes[] memory updateDatas = new bytes[](1);
        updateDatas[0] = offChainPrice.vaa;

        pyth.updatePriceFeeds{value: msg.value}(updateDatas);

        updatedVaa[vaa] = true;
    }

    /**
     * @inheritdoc IOracleProviderPullBased
     */
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

    function baseDecimalPrice(int256 pythPrice, int32 expo) internal pure returns (int256) {
        int256 pythDecimal = int256(10 ** int256(expo).abs());
        return
            expo > 0
                ? int256(pythPrice).mul(BASE).mul(pythDecimal)
                : int256(pythPrice).mul(BASE).div(pythDecimal);
    }

    function pythPriceToOracleVersion(
        PythStructs.Price memory price,
        uint256 version
    ) internal pure returns (OracleVersion memory) {
        return
            OracleVersion({
                version: version,
                timestamp: price.publishTime,
                price: baseDecimalPrice(price.price, price.expo)
            });
    }

    /**
     * @inheritdoc IOracleProviderPullBased
     */
    function parseExtraData(
        bytes calldata extraData
    ) external view override returns (OracleVersion memory) {
        PythOffchainPrice memory offChainPrice = decodeOffchainData(extraData);
        return
            OracleVersion(
                lastSyncedVersionIndex + 1,
                offChainPrice.publishTime,
                baseDecimalPrice(offChainPrice.price, offChainPrice.expo)
            );
    }
}
