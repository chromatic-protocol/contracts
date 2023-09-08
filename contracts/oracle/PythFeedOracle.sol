// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./interfaces/IOracleProvider.sol";
import "@pythnetwork/pyth-sdk-solidity/AbstractPyth.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";

// 0xff1a0f4744e8582DF1aE09D5611b887B6a12925C arb
contract PythFeedOracle is IOracleProvider {
    using SignedMath for int256;

    error PriceFeedNotExist();

    int256 private constant DECIMALS = 18;

    /// @dev Pyth address
    AbstractPyth public immutable pyth;

    /// @dev The id of pyth price feed
    bytes32 public immutable priceFeedId;

    /// @dev The description of the Oracle Provider('ETH/USD', 'BTC/USD'...)
    string private _description;

    /// @dev Last version seen when `sync` was called
    uint256 private lastSyncedVersion;
    
    /// @dev Last publishTime seen when `sync` was called
    uint256 private lastSyncedPublishTime;

    /// @dev Mapping of version to OracleVersion
    mapping(uint256 => OracleVersion) private oracleVersions;

    /**
     * @notice Initializes the contract state
     * @param pyth_ Pyth address
     * @param priceFeedId_ The id of pyth price feed
     * @param description_ The description of the Oracle Provider('ETH/USD', 'BTC/USD'...)
     */
    constructor(AbstractPyth pyth_, bytes32 priceFeedId_, string memory description_) {
        pyth = pyth_;
        if(!pyth.priceFeedExists(priceFeedId_)){
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

            int256 decimalGap = DECIMALS + latestPrice.expo;
            uint256 absDecimalNumber = decimalGap.abs();
            uint256 decimal = uint256(10) ** absDecimalNumber;

            oracleVersions[lastSyncedVersion] = OracleVersion({
                version: lastSyncedVersion,
                timestamp: latestPrice.publishTime,
                price: decimalGap < 0
                    ? latestPrice.price / int256(decimal)
                    : latestPrice.price * int256(decimal)
            });
        }
        return oracleVersions[lastSyncedVersion];
    }

    /**
     * @inheritdoc IOracleProvider
     */
    function currentVersion() public view returns (OracleVersion memory oracleVersion) {
        return oracleVersions[lastSyncedVersion];
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
}
