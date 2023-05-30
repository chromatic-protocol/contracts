// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Base64} from '@openzeppelin/contracts/utils/Base64.sol';
import {ERC1155Supply, ERC1155} from '@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol';
import {SafeCast} from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import {SignedMath} from '@openzeppelin/contracts/utils/math/SignedMath.sol';
import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';
import {LpTokenLib} from '@usum/core/libraries/LpTokenLib.sol';
import {IUSUMMarket} from '@usum/core/interfaces/IUSUMMarket.sol';

contract USUMLpToken is ERC1155Supply {
    using Strings for uint256;
    using Strings for uint128;
    using SafeCast for uint256;
    using SignedMath for int256;

    IUSUMMarket public immutable market;
    string private imageUri;

    error OnlyAccessableByMarket();

    modifier onlyMarket() {
        if (address(market) != (msg.sender)) revert OnlyAccessableByMarket();
        _;
    }

    constructor() ERC1155('') {
        market = IUSUMMarket(msg.sender);
    }

    function mint(address to, uint256 id, uint256 amount, bytes calldata data) external onlyMarket {
        _mint(to, id, amount, data);
    }

    function burn(address from, uint256 id, uint256 amount) external onlyMarket {
        _burn(from, id, amount);
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    // only Owner
    function setImageUri(string memory _imageUri) public {
        imageUri = _imageUri;
    }

    function uri(uint256 id) public view override returns (string memory) {
        int16 tradingFeeRate = decodeId(id);

        string memory indexName = market.oracleProvider().description();
        bytes memory metadata = abi.encodePacked(
            //prettier-ignore
            //TODO add properties
            '{"name": "USUM Lp#',
            id.toString(),
            '", "description": "',
            indexName,
            ' ',
            tradingFeeRate < 0 ? 'Short ' : 'Long ',
            int256(tradingFeeRate).abs().toString(),
            '", "image":"',
            imageUri,
            '"',
            '}'
        );

        return string(abi.encodePacked('data:application/json;base64,', Base64.encode(metadata)));
    }

    function encodeId(int16 tradingFeeRate) internal pure returns (uint256 id) {
        id = LpTokenLib.encodeId(tradingFeeRate);
    }

    function decodeId(uint256 id) internal pure returns (int16 tradingFeeRate) {
        tradingFeeRate = LpTokenLib.decodeId(id);
    }
}
