// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/interfaces/IERC1155MetadataURI.sol";
import {ERC1155Supply, ERC1155} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {CLBTokenLib} from "@chromatic/core/libraries/CLBTokenLib.sol";
import {IChromaticMarket} from "@chromatic/core/interfaces/IChromaticMarket.sol";
import {ICLBToken} from "@chromatic/core/interfaces/ICLBToken.sol";

contract CLBToken is ERC1155Supply, ICLBToken {
    using Strings for uint256;
    using Strings for uint128;
    using SafeCast for uint256;
    using SignedMath for int256;

    uint8 public constant decimals = 18;

    IChromaticMarket public immutable market;
    string private imageUri;

    error OnlyAccessableByMarket();

    modifier onlyMarket() {
        if (address(market) != (msg.sender)) revert OnlyAccessableByMarket();
        _;
    }

    constructor() ERC1155("") {
        market = IChromaticMarket(msg.sender);
    }

    function totalSupply(
        uint256 id
    ) public view virtual override(ERC1155Supply, ICLBToken) returns (uint256) {
        return super.totalSupply(id);
    }

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external override onlyMarket {
        _mint(to, id, amount, data);
    }

    function burn(address from, uint256 id, uint256 amount) external override onlyMarket {
        _burn(from, id, amount);
    }

    // only Owner
    function setImageUri(string memory _imageUri) public {
        imageUri = _imageUri;
    }

    function uri(
        uint256 id
    ) public view override(ERC1155, IERC1155MetadataURI) returns (string memory) {
        int16 tradingFeeRate = decodeId(id);

        string memory indexName = market.oracleProvider().description();
        bytes memory metadata = abi.encodePacked(
            //prettier-ignore
            //TODO add properties
            '{"name": "CLB#',
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

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(metadata)));
    }

    function encodeId(int16 tradingFeeRate) internal pure returns (uint256 id) {
        id = CLBTokenLib.encodeId(tradingFeeRate);
    }

    function decodeId(uint256 id) internal pure returns (int16 tradingFeeRate) {
        tradingFeeRate = CLBTokenLib.decodeId(id);
    }
}
