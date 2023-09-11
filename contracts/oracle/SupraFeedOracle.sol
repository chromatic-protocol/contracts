// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/IOracleProvider.sol";
import "./types/SupraSValueFeed.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SupraFeedOracle is IOracleProvider {
    using SafeMath for uint256;

    error PriceFeedNotExist();

    uint256 private constant BASE = 1e18;

    /// @dev Supra feed address (https://supraoracles.com/docs/price-feeds/networks)
    SupraSValueFeed public immutable feed;

    /// @dev The index of supra trading pair (https://supraoracles.com/docs/price-feeds/trading-pairs)
    uint64 public immutable pairIndex;

    /// @dev The description of the Oracle Provider('ETH/USD', 'BTC/USD'...)
    string private _description;

    /// @dev Last version seen when `sync` was called
    uint256 private lastSyncedVersion;

    /// @dev Last publishTime seen when `sync` was called
    uint256 private lastSyncedTimestamp;

    /// @dev Mapping of version to OracleVersion
    mapping(uint256 => OracleVersion) private oracleVersions;

    /**
     * @notice Initializes the contract state
     * @param feed_ Supra address (https://supraoracles.com/docs/price-feeds/networks)
     * @param pairIndex_ The index of supra trading pair (https://supraoracles.com/docs/price-feeds/trading-pairs)
     * @param description_ The description of the Oracle Provider('ETH/USD', 'BTC/USD'...)
     */
    constructor(SupraSValueFeed feed_, uint64 pairIndex_, string memory description_) {
        feed = feed_;
        pairIndex = pairIndex_;
        _description = description_;
        sync();
    }

    /**
     * @inheritdoc IOracleProvider
     */
    function sync() public returns (OracleVersion memory) {
        (uint256 round, uint256 supraDecimal, uint256 timestamp, uint256 price) = feed.getPrice(
            pairIndex
        );
        if (round == 0) {
            revert PriceFeedNotExist();
        }
        if (lastSyncedTimestamp < timestamp) {
            lastSyncedVersion++;
            lastSyncedTimestamp = timestamp;

            oracleVersions[lastSyncedVersion] = OracleVersion({
                version: lastSyncedVersion,
                timestamp: timestamp,
                price: int256(price.mul(BASE).div(10 ** supraDecimal))
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
        return "supra";
    }
}
