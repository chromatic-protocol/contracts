// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {ERC1155Supply, ERC1155} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {IUSUMMarketState} from "@usum/core/interfaces/market/IUSUMMarketState.sol";
import {LpTokenLib} from "@usum/core/libraries/LpTokenLib.sol";

abstract contract LpToken is ERC1155Supply, IERC1155Receiver {
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
        id = LpTokenLib.encodeId(tradingFeeRate);
    }

    function decodeId(uint256 id) internal pure returns (int16 tradingFeeRate) {
        tradingFeeRate = LpTokenLib.decodeId(id);
    }


    // for burnCallBack
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    // for burnCallBack
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
