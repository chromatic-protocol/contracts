// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import "../interfaces/ISupraSValueFeed.sol";
import "./ChainlinkRound.sol";

type SupraSValueFeed is address;
using SupraSValueFeedLib for SupraSValueFeed global;

library SupraSValueFeedLib {
    function getPrice(
        SupraSValueFeed self,
        uint64 pareIndex
    ) internal view returns (uint256 round, uint256 decimal, uint256 timestamp, uint256 price) {
        (bytes32 data, ) = ISupraSValueFeed(SupraSValueFeed.unwrap(self)).getSvalue(pareIndex);

        round = bytesToUint256(abi.encodePacked(data >> 192));
        decimal = bytesToUint256(abi.encodePacked((data << 64) >> 248));
        timestamp = bytesToUint256(abi.encodePacked((data << 72) >> 192));
        price = bytesToUint256(abi.encodePacked((data << 136) >> 160));
    }

    function bytesToUint256(bytes memory _bs) internal pure returns (uint256 value) {
        require(_bs.length == 32, "bytes length is not 32.");
        assembly {
            value := mload(add(_bs, 0x20))
        }
    }
}