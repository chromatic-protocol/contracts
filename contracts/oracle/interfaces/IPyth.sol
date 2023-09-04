/**
 *Submitted for verification at Arbiscan.io on 2023-08-03
 */

// https://github.com/pyth-network/pyth-sdk-solidity
// @pythnetwork/pyth-sdk-solidity



pragma solidity >=0.8.0 <0.9.0;

interface IPyth {
    struct Price {
        int64 price;
        uint64 conf;
        int32 expo;
        uint publishTime;
    }

    struct PriceFeed {
        bytes32 id;
        Price price;
        Price emaPrice;
    }

    event PriceFeedUpdate(bytes32 indexed id, uint64 publishTime, int64 price, uint64 conf);

    event BatchPriceFeedUpdate(uint16 chainId, uint64 sequenceNumber);

    error InvalidArgument();

    error InvalidUpdateDataSource();

    error InvalidUpdateData();

    error InsufficientFee();

    error NoFreshUpdate();

    error PriceFeedNotFoundWithinRange();

    error PriceFeedNotFound();

    error StalePrice();

    error InvalidWormholeVaa();

    error InvalidGovernanceMessage();

    error InvalidGovernanceTarget();

    error InvalidGovernanceDataSource();

    error OldGovernanceMessage();

    error InvalidWormholeAddressToSet();

    function getValidTimePeriod() external view returns (uint validTimePeriod);

    function getPrice(bytes32 id) external view returns (Price memory price);

    function getEmaPrice(bytes32 id) external view returns (Price memory price);

    function getPriceUnsafe(bytes32 id) external view returns (Price memory price);

    function getPriceNoOlderThan(bytes32 id, uint age) external view returns (Price memory price);

    function getEmaPriceUnsafe(bytes32 id) external view returns (Price memory price);

    function getEmaPriceNoOlderThan(
        bytes32 id,
        uint age
    ) external view returns (Price memory price);

    function updatePriceFeeds(bytes[] calldata updateData) external payable;

    function updatePriceFeedsIfNecessary(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64[] calldata publishTimes
    ) external payable;

    function getUpdateFee(bytes[] calldata updateData) external view returns (uint feeAmount);

    function parsePriceFeedUpdates(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    ) external payable returns (PriceFeed[] memory priceFeeds);

    function priceFeedExists(bytes32 id) external view returns (bool exists);
}
