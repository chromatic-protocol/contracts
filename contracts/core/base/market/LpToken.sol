// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {ERC1155Supply, ERC1155} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {IUSUMMarketState} from "@usum/core/interfaces/market/IUSUMMarketState.sol";

// fee pool slot
// 0.01% ~ 0.09% 9개, (0.01% 단위)
// 0.1% ~ 0.9% 9개, (0.1% 단위)
// 1% ~ 9% 9개, (1% 단위)
// 10% ~ 50% 9개 (5% 단위)

// 예치 증서는 동일한 fee pool slot끼리는 동일한 수량의 증서는 같은 가치를 가지고,
// 다른 slot의 토큰은 다른 slot의 예치 증서와 다른 가치를 가지므로 예치증서는 ERC1155 토큰으로 제공합니다

// Liquidity
//  inherits
//      IERC1155
//  fields
//      lpSlots: LpSlotSet
//  methods
//      mint()
//          liquidity = lpSlots.mint()
//          liquidity 수량만큼 token mint
//      burn()
//          amount = lpSlots.burn()
//          amount 만큼 settlement token transfer
// TODO metadata
// TODO 나중에 openPosition 할 때 수수료 저렴한거 부터 돌려야되는데 잔고가 있는 슬롯만 리스트로 관리(sort포함) 해야편할까?
abstract contract LpToken is ERC1155Supply {
    using Strings for uint256;
    using Strings for uint128;
    using SafeCast for uint256;
    using SignedMath for int256;

    uint256 constant DIRECTION_PRECISION = 10 ** 10;

    string private imageUri;

    constructor() ERC1155("") {}

    function decimals() public pure returns (uint8) {
        return 18;
    }

    // only Owner
    function setImageUri(string memory _imageUri) public {
        imageUri = _imageUri;
    }

    function uri(uint256 id) public view override returns (string memory) {
        int16 tradingFeeRate = decodeId(id);

        string memory indexName = IUSUMMarketState(address(this))
            .oracleProvider()
            .description();
        bytes memory metadata = abi.encodePacked(
            //prettier-ignore
            //TODO add properties
            '{"name": "USUM Lp#',
            id.toString(),
            '", "description": "',
            indexName,
            " ",
            tradingFeeRate < 0 ? "Short " : "Long ",
            int256(tradingFeeRate).abs().toString(),
            '", "image":"',
            imageUri,
            '"',
            "}"
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(metadata)
                )
            );
    }

    function encodeId(int16 tradingFeeRate) internal pure returns (uint256 id) {
        uint256 absFeeRate = int256(tradingFeeRate).abs();
        id = tradingFeeRate < 0 ? absFeeRate + DIRECTION_PRECISION : absFeeRate;
    }

    function decodeId(uint256 id) internal pure returns (int16 tradingFeeRate) {
        if (id >= DIRECTION_PRECISION) {
            tradingFeeRate = -int16((id - DIRECTION_PRECISION).toUint16());
        } else {
            tradingFeeRate = int16(id.toUint16());
        }
    }
}
