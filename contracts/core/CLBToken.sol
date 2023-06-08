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
import {BPS} from "@chromatic/core/libraries/Constants.sol";

contract CLBToken is ERC1155Supply, ICLBToken {
    using Strings for uint256;
    using Strings for uint128;
    using SafeCast for uint256;
    using SignedMath for int256;

    uint8 public constant override decimals = 18;

    IChromaticMarket public immutable market;

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

    function name(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked("CLB - ", description(id)));
    }

    function description(uint256 id) public view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    _tokenSymbol(),
                    " - ",
                    _indexName(),
                    " ",
                    _formatedFeeRate(decodeId(id))
                )
            );
    }

    function image(uint256 id) public view override returns (string memory) {
        int16 tradingFeeRate = decodeId(id);
        return
            string(
                abi.encodePacked(
                    "data:image/svg+xml;base64,",
                    Base64.encode(
                        _svg(
                            _formatedFeeRate(tradingFeeRate),
                            _tokenSymbol(),
                            _indexName(),
                            _color(tradingFeeRate)
                        )
                    )
                )
            );
    }

    function uri(
        uint256 id
    ) public view override(ERC1155, IERC1155MetadataURI) returns (string memory) {
        bytes memory metadata = abi.encodePacked(
            '{"name": "',
            name(id),
            '", "description": "',
            description(id),
            '", "decimals": "',
            uint256(decimals).toString(),
            '", "image":"',
            image(id),
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

    function _tokenSymbol() private view returns (string memory) {
        return market.settlementToken().symbol();
    }

    function _indexName() private view returns (string memory) {
        return market.oracleProvider().description();
    }

    function _formatedFeeRate(int16 feeRate) private pure returns (bytes memory) {
        uint256 absFeeRate = uint16(feeRate < 0 ? -(feeRate) : feeRate);

        uint256 integerPart = absFeeRate / BPS;
        uint256 fractionalPart = (absFeeRate % BPS) / (BPS / 100);

        return
            abi.encodePacked(
                feeRate < 0 ? "-" : "+",
                integerPart.toString(),
                ".",
                fractionalPart.toString(),
                "%"
            );
    }

    function _color(int16 feeRate) private pure returns (string memory) {
        uint256 absFeeRate = uint16(feeRate < 0 ? -(feeRate) : feeRate);

        if (absFeeRate >= BPS / 10) {
            // feeRate >= 10%  or feeRate <= -10%
            return feeRate > 0 ? "#FFCE94" : "#8591FF";
        } else if (absFeeRate >= BPS / 100) {
            // 10% > feeRate >= 1% or -1% >= feeRate > -10%
            return feeRate > 0 ? "#FFAB5E" : "#5988FF";
        } else if (absFeeRate >= BPS / 1000) {
            // 1% > feeRate >= 0.1% or -0.1% >= feeRate > -1%
            return feeRate > 0 ? "#FF975A" : "#2FB1FA";
        } else if (absFeeRate >= BPS / 10000) {
            // 0.1% > feeRate >= 0.01% or -0.01% >= feeRate > -0.1%
            return feeRate > 0 ? "#FE8B63" : "#6EC4F9";
        }
        // feeRate == 0%
        return "#000000";
    }

    function _svg(
        bytes memory humanReadableId,
        string memory symbol,
        string memory index,
        string memory color
    ) private pure returns (bytes memory) {
        bytes memory stopTags = _stopTags(color);
        bytes memory content = abi.encodePacked(
            "<g>",
            abi.encodePacked(
                '<linearGradient id="SVGID_1_" gradientUnits="userSpaceOnUse" x1="120" y1="416.01" x2="120" y2="0" gradientTransform="matrix(1 0 0 -1 0 480)">',
                stopTags,
                "</linearGradient>"
                '<polygon style="fill:url(#SVGID_1_);" points="80,480 160,480 160,63.99 80,63.99"/>'
                '<linearGradient id="SVGID_2_" gradientUnits="userSpaceOnUse" x1="200" y1="352.03" x2="200" y2="0" gradientTransform="matrix(1 0 0 -1 0 480)">',
                stopTags,
                "</linearGradient>"
                '<polygon style="fill:url(#SVGID_2_);" points="160,480 240,480 240,127.97 160,127.97"/>'
                '<linearGradient id="SVGID_3_" gradientUnits="userSpaceOnUse" x1="280" y1="288.04" x2="280" y2="0" gradientTransform="matrix(1 0 0 -1 0 480)">',
                stopTags,
                "</linearGradient>"
                '<polygon style="fill:url(#SVGID_3_);" points="240,480 320,480 320,191.96 240,191.96"/>'
            ),
            abi.encodePacked(
                '<linearGradient id="SVGID_4_" gradientUnits="userSpaceOnUse" x1="360" y1="224.05" x2="360" y2="9.094947e-13" gradientTransform="matrix(1 0 0 -1 0 480)">',
                stopTags,
                "</linearGradient>"
                '<polygon style="fill:url(#SVGID_4_);" points="320,480 400,480 400,255.95 320,255.95"/>'
                '<linearGradient id="SVGID_5_" gradientUnits="userSpaceOnUse" x1="440" y1="160.06" x2="440" y2="9.094947e-13" gradientTransform="matrix(1 0 0 -1 0 480)">',
                stopTags,
                "</linearGradient>"
                '<polygon style="fill:url(#SVGID_5_);" points="400,480 480,480 480,319.94 400,319.94"/>'
                '<linearGradient id="SVGID_6_" gradientUnits="userSpaceOnUse" x1="40" y1="480" x2="40" y2="0" gradientTransform="matrix(1 0 0 -1 0 480)">',
                stopTags,
                "</linearGradient>"
                '<polygon style="fill:url(#SVGID_6_);" points="0,480 80,480 80,0 0,0"/>'
            ),
            "</g>"
            "<g>",
            abi.encodePacked(
                '<linearGradient id="SVGID_7_" gradientUnits="userSpaceOnUse" x1="140" y1="396.01" x2="140" y2="0" gradientTransform="matrix(1 0 0 -1 0 480)">',
                stopTags,
                "</linearGradient>"
                '<polygon style="fill:url(#SVGID_7_);" points="100,480 180,480 180,83.99 100,83.99"/>'
                '<linearGradient id="SVGID_8_" gradientUnits="userSpaceOnUse" x1="220" y1="332.03" x2="220" y2="0" gradientTransform="matrix(1 0 0 -1 0 480)">',
                stopTags,
                "</linearGradient>"
                '<polygon style="fill:url(#SVGID_8_);" points="180,480 260,480 260,147.97 180,147.97"/>'
                '<linearGradient id="SVGID_9_" gradientUnits="userSpaceOnUse" x1="300" y1="268.04" x2="300" y2="0" gradientTransform="matrix(1 0 0 -1 0 480)">',
                stopTags,
                "</linearGradient>"
                '<polygon style="fill:url(#SVGID_9_);" points="260,480 340,480 340,211.96 260,211.96"/>'
            ),
            abi.encodePacked(
                '<linearGradient id="SVGID_10_" gradientUnits="userSpaceOnUse" x1="380" y1="204.05" x2="380" y2="9.094947e-13" gradientTransform="matrix(1 0 0 -1 0 480)">',
                stopTags,
                "</linearGradient>"
                '<polygon style="fill:url(#SVGID_10_);" points="340,480 420,480 420,275.95 340,275.95"/>'
                '<linearGradient id="SVGID_11_" gradientUnits="userSpaceOnUse" x1="450" y1="140.06" x2="450" y2="9.094947e-13" gradientTransform="matrix(1 0 0 -1 0 480)">',
                stopTags,
                "</linearGradient>"
                '<polygon style="fill:url(#SVGID_11_);" points="420,480 480,480 480,339.94 420,339.94"/>'
                '<linearGradient id="SVGID_12_" gradientUnits="userSpaceOnUse" x1="50" y1="460" x2="50" y2="0" gradientTransform="matrix(1 0 0 -1 0 480)">',
                stopTags,
                "</linearGradient>"
                '<polygon style="fill:url(#SVGID_12_);" points="0,480 100,480 100,20 0,20"/>'
            ),
            "</g>"
            '<text transform="matrix(1 0 0 1 245.9107 90.1792)" style="fill:#FFFFFF; font-size:64px;">',
            humanReadableId,
            "</text>"
            "<g>"
            '<text transform="matrix(1 0 0 1 194.9673 146.5815)" style="fill:#FFFFFF; font-size:32px;">',
            symbol,
            " - ",
            index,
            "</text>"
            "</g>"
            "<g>"
            '<text transform="matrix(1 0 0 1 33.314 404.23)" style="font-size:28px;">ERC-1155</text>'
            '<text transform="matrix(1 0 0 1 33.314 443.02)" style="font-size:28px;">CHROMATIC </text>'
            '<text transform="matrix(1 0 0 1 206.914 443.02)" style="font-size:28px;">Liquidity Bin Token</text>'
            "</g>"
        );
        return
            abi.encodePacked(
                '<?xml version="1.0" encoding="utf-8"?>'
                '<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" viewBox="0 0 480 480" style="enable-background:new 0 0 480 480;" xml:space="preserve">'
                "<g>"
                '<rect width="480" height="480"/>',
                content,
                "</g>"
                "</svg>"
            );
    }

    function _stopTags(string memory color) private pure returns (bytes memory) {
        return
            abi.encodePacked(
                '<stop offset="0" style="stop-color:',
                color,
                '; stop-opacity:0"/>',
                '<stop offset="1" style="stop-color:',
                color,
                '"/>'
            );
    }
}
