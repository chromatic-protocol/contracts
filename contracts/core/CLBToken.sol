// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/interfaces/IERC1155MetadataURI.sol";
import {ERC1155Supply, ERC1155} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";
import {BPS} from "@chromatic-protocol/contracts/core/libraries/Constants.sol";

/**
 * @title CLBToken
 * @dev CLBToken is an ERC1155 token contract that represents Liquidity Bin tokens.
 *      CLBToken allows minting and burning of tokens by the Chromatic Market contract.
 */
contract CLBToken is ICLBToken, ERC1155Supply {
    using Strings for uint256;
    using Strings for uint128;
    using SafeCast for uint256;
    using SignedMath for int256;

    IChromaticMarket public immutable market;

    /**
     * @dev Throws an error indicating that the caller is not a registered market.
     */
    error OnlyAccessableByMarket();

    /**
     * @dev Modifier to restrict access to the Chromatic Market contract.
     *      Only the market contract is allowed to call functions with this modifier.
     *      Reverts with an error if the caller is not the market contract.
     */
    modifier onlyMarket() {
        if (address(market) != (msg.sender)) revert OnlyAccessableByMarket();
        _;
    }

    /**
     * @dev Initializes the CLBToken contract.
     *      The constructor sets the market contract address as the caller.
     */
    constructor() ERC1155("") {
        market = IChromaticMarket(msg.sender);
    }

    /**
     * @inheritdoc ICLBToken
     */
    function decimals() public view override returns (uint8) {
        return market.settlementToken().decimals();
    }

    /**
     * @inheritdoc ICLBToken
     */
    function totalSupply(
        uint256 id
    ) public view virtual override(ERC1155Supply, ICLBToken) returns (uint256) {
        return super.totalSupply(id);
    }

    /**
     * @inheritdoc ICLBToken
     */
    function totalSupplyBatch(
        uint256[] memory ids
    ) public view virtual override returns (uint256[] memory) {
        uint256[] memory supplies = new uint256[](ids.length);
        for (uint256 i; i < ids.length; ) {
            supplies[i] = super.totalSupply(ids[i]);

            unchecked {
                i++;
            }
        }
        return supplies;
    }

    /**
     * @inheritdoc ICLBToken
     * @dev This function can only be called by the Chromatic Market contract.
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external override onlyMarket {
        _mint(to, id, amount, data);
    }

    /**
     * @inheritdoc ICLBToken
     * @dev This function can only be called by the Chromatic Market contract.
     */
    function burn(address from, uint256 id, uint256 amount) external override onlyMarket {
        _burn(from, id, amount);
    }

    /**
     * @inheritdoc ICLBToken
     */
    function name(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked("CLB - ", description(id)));
    }

    /**
     * @inheritdoc ICLBToken
     */
    function description(uint256 id) public view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    _tokenSymbol(),
                    " - ",
                    _indexName(),
                    " ",
                    _formattedFeeRate(decodeId(id))
                )
            );
    }

    /**
     * @inheritdoc ICLBToken
     */
    function image(uint256 id) public view override returns (string memory) {
        int16 tradingFeeRate = decodeId(id);
        return
            string(
                abi.encodePacked(
                    "data:image/svg+xml;base64,",
                    Base64.encode(_svg(tradingFeeRate, _tokenSymbol(), _indexName()))
                )
            );
    }

    /**
     * @inheritdoc IERC1155MetadataURI
     */
    function uri(
        uint256 id
    ) public view override(ERC1155, IERC1155MetadataURI) returns (string memory) {
        bytes memory metadata = abi.encodePacked(
            '{"name": "',
            name(id),
            '", "description": "',
            description(id),
            '", "decimals": "',
            uint256(decimals()).toString(),
            '", "image":"',
            image(id),
            '"',
            "}"
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(metadata)));
    }

    /**
     * @dev Decodes a token ID into a trading fee rate.
     * @param id The token ID to decode.
     * @return tradingFeeRate The decoded trading fee rate.
     */
    function decodeId(uint256 id) internal pure returns (int16 tradingFeeRate) {
        tradingFeeRate = CLBTokenLib.decodeId(id);
    }

    /**
     * @dev Retrieves the symbol of the settlement token.
     * @return The symbol of the settlement token.
     */
    function _tokenSymbol() private view returns (string memory) {
        return market.settlementToken().symbol();
    }

    /**
     * @dev Retrieves the name of the index.
     * @return The name of the index.
     */
    function _indexName() private view returns (string memory) {
        return market.oracleProvider().description();
    }

    /**
     * @dev Formats a fee rate into a human-readable string.
     * @param feeRate The fee rate to format.
     * @return The formatted fee rate as a bytes array.
     */
    function _formattedFeeRate(int16 feeRate) private pure returns (bytes memory) {
        uint256 absFeeRate = uint16(feeRate < 0 ? -(feeRate) : feeRate);

        uint256 pct = BPS / 100;
        uint256 integerPart = absFeeRate / pct;
        uint256 fractionalPart = absFeeRate % pct;

        //slither-disable-next-line uninitialized-local
        bytes memory fraction;
        if (fractionalPart != 0) {
            uint256 fractionalPart1 = fractionalPart / (pct / 10);
            uint256 fractionalPart2 = fractionalPart % (pct / 10);

            fraction = bytes(".");
            if (fractionalPart2 == 0) {
                fraction = abi.encodePacked(fraction, fractionalPart1.toString());
            } else {
                fraction = abi.encodePacked(
                    fraction,
                    fractionalPart1.toString(),
                    fractionalPart2.toString()
                );
            }
        }

        return abi.encodePacked(feeRate < 0 ? "-" : "+", integerPart.toString(), fraction, "%");
    }

    uint256 private constant _W = 480;
    uint256 private constant _H = 480;
    string private constant _WS = "480";
    string private constant _HS = "480";
    uint256 private constant _BARS = 9;

    function _svg(
        int16 feeRate,
        string memory symbol,
        string memory index
    ) private pure returns (bytes memory) {
        bytes memory formattedFeeRate = _formattedFeeRate(feeRate);
        string memory color = _color(feeRate);
        bool long = feeRate > 0;

        bytes memory text = abi.encodePacked(
            '<text class="st13 st14" font-size="64" transform="translate(440 216.852)" text-anchor="end">',
            formattedFeeRate,
            "</text>"
            '<text class="st13 st16" font-size="28" transform="translate(440 64.036)" text-anchor="end">',
            symbol,
            "</text>"
            '<path d="M104.38 40 80.74 51.59V40L63.91 52.17v47.66L80.74 112v-11.59L104.38 112zm-43.34 0L50.87 52.17v47.66L61.04 112zm-16.42 0L40 52.17v47.66L44.62 112z" class="st13" />'
            '<text class="st13 st14 st18" transform="translate(440 109.356)" text-anchor="end">',
            index,
            " Market</text>"
            '<path fill="none" stroke="#fff" stroke-miterlimit="10" d="M440 140H40" opacity=".5" />'
            '<text class="st13 st14 st18" transform="translate(40 438.578)">CLB</text>'
            '<text class="st13 st16" font-size="22" transform="translate(107.664 438.578)">Chromatic Liquidity Bin Token</text>'
            '<text class="st13 st16" font-size="16" transform="translate(54.907 390.284)">ERC-1155</text>'
            '<path fill="none" stroke="#fff" stroke-miterlimit="10" d="M132.27 399.77h-84c-4.42 0-8-3.58-8-8v-14c0-4.42 3.58-8 8-8h84c4.42 0 8 3.58 8 8v14c0 4.42-3.58 8-8 8z" />'
        );

        return
            abi.encodePacked(
                '<?xml version="1.0" encoding="utf-8"?>'
                '<svg xmlns="http://www.w3.org/2000/svg" xml:space="preserve" x="0" y="0" version="1.1" viewBox="0 0 ',
                _WS,
                " ",
                _HS,
                '">'
                "<style>"
                "  .st13 {"
                "    fill: #fff"
                "  }"
                "  .st14 {"
                '    font-family: "NotoSans-Bold";'
                "  }"
                "  .st16 {"
                '    font-family: "NotoSans-Regular";'
                "  }"
                "  .st18 {"
                "    font-size: 32px"
                "  }"
                "</style>",
                _background(long),
                _bars(long, color, _activeBar(feeRate)),
                text,
                "</svg>"
            );
    }

    function _background(bool long) private pure returns (bytes memory) {
        return
            abi.encodePacked(
                '<linearGradient id="bg" x1="',
                long ? "0" : _WS,
                '" x2="',
                long ? _WS : "0",
                '" y1="',
                _HS,
                '" y2="0" gradientUnits="userSpaceOnUse">',
                long
                    ? '<stop offset="0" />'
                    '<stop offset=".3" stop-color="#010302" />'
                    '<stop offset=".5" stop-color="#040b07" />'
                    '<stop offset=".6" stop-color="#0a1910" />'
                    '<stop offset=".7" stop-color="#132e1d" />'
                    '<stop offset=".8" stop-color="#1d482e" />'
                    '<stop offset=".9" stop-color="#2b6843" />'
                    '<stop offset="1" stop-color="#358153" />'
                    : '<stop offset="0" style="stop-color:#000" />'
                    '<stop offset=".3" style="stop-color:#030101" />'
                    '<stop offset=".4" style="stop-color:#0b0605" />'
                    '<stop offset=".6" style="stop-color:#190f0b" />'
                    '<stop offset=".7" style="stop-color:#2e1a13" />'
                    '<stop offset=".8" style="stop-color:#482a1f" />'
                    '<stop offset=".9" style="stop-color:#683c2c" />'
                    '<stop offset="1" style="stop-color:#8e523c" />',
                "</linearGradient>"
                '<path fill="url(#bg)" d="M0 0h',
                _WS,
                "v",
                _HS,
                'H0z" />'
            );
    }

    function _activeBar(int16 feeRate) private pure returns (uint256) {
        uint256 absFeeRate = uint16(feeRate < 0 ? -(feeRate) : feeRate);

        if (absFeeRate >= BPS / 10) {
            return (absFeeRate / (BPS / 10 / 2)) - 2;
        } else if (absFeeRate >= BPS / 100) {
            return (absFeeRate / (BPS / 100)) - 1;
        } else if (absFeeRate >= BPS / 1000) {
            return (absFeeRate / (BPS / 1000)) - 1;
        } else if (absFeeRate >= BPS / 10000) {
            return (absFeeRate / (BPS / 10000)) - 1;
        }
        return 0;
    }

    function _bars(
        bool long,
        string memory color,
        uint256 activeBar
    ) private pure returns (bytes memory bars) {
        for (uint256 i; i < _BARS; ) {
            bars = abi.encodePacked(bars, _bar(i, long, color, i == activeBar));

            unchecked {
                i++;
            }
        }
    }

    function _bar(
        uint256 barIndex,
        bool long,
        string memory color,
        bool active
    ) private pure returns (bytes memory) {
        (uint256 pos, uint256 width, uint256 height, uint256 hDelta) = _barAttributes(
            barIndex,
            long
        );

        string memory gX = _gradientX(barIndex, long);
        string memory gY = (_H - height).toString();

        bytes memory stop = abi.encodePacked(
            '<stop offset="0" stop-color="',
            color,
            '" stop-opacity="0"/>'
            '<stop offset="1" stop-color="',
            color,
            '"/>'
        );
        bytes memory path = _path(barIndex, long, pos, width, height, hDelta);
        bytes memory bar = abi.encodePacked(
            '<linearGradient id="bar',
            barIndex.toString(),
            '" x1="',
            gX,
            '" x2="',
            gX,
            '" y1="',
            gY,
            '" y2="',
            _HS,
            '" gradientUnits="userSpaceOnUse">',
            stop,
            "</linearGradient>",
            path
        );

        if (active) {
            bytes memory edge = _edge(long, pos, width, height);
            return abi.encodePacked(bar, bar, bar, edge);
        }
        return bar;
    }

    function _edge(
        bool long,
        uint256 pos,
        uint256 width,
        uint256 height
    ) private pure returns (bytes memory) {
        string memory _epos = (long ? pos + width : pos - width).toString();

        bytes memory path = abi.encodePacked(
            '<path fill="url(#edge)" d="M',
            _epos,
            " ",
            _HS,
            "h",
            long ? "-" : "",
            "2v-",
            height.toString(),
            "H",
            _epos,
            'z"/>'
        );
        return
            abi.encodePacked(
                '<linearGradient id="edge" x1="',
                _epos,
                '" x2="',
                _epos,
                '" y1="',
                _HS,
                '" y2="',
                (_H - height).toString(),
                '" gradientUnits="userSpaceOnUse">'
                '<stop offset="0" stop-color="#fff" stop-opacity="0"/>'
                '<stop offset=".5" stop-color="#fff" stop-opacity=".5"/>'
                '<stop offset="1" stop-color="#fff" stop-opacity="0"/>'
                "</linearGradient>",
                path
            );
    }

    function _path(
        uint256 barIndex,
        bool long,
        uint256 pos,
        uint256 width,
        uint256 height,
        uint256 hDelta
    ) private pure returns (bytes memory) {
        string memory _w = width.toString();
        bytes memory _h = abi.encodePacked("h", long ? "" : "-", _w);
        bytes memory _l = abi.encodePacked("l", long ? "-" : "", _w, " ", hDelta.toString());
        return
            abi.encodePacked(
                '<path fill="url(#bar',
                barIndex.toString(),
                ')" d="M',
                pos.toString(),
                " ",
                _HS,
                _h,
                "v-",
                height.toString(),
                _l,
                'z"/>'
            );
    }

    function _barAttributes(
        uint256 barIndex,
        bool long
    ) private pure returns (uint256 pos, uint256 width, uint256 height, uint256 hDelta) {
        uint256[_BARS] memory widths = [uint256(44), 45, 48, 51, 53, 55, 58, 62, 64];
        uint256[_BARS] memory heights = [uint256(480), 415, 309, 240, 185, 144, 111, 86, 67];
        uint256[_BARS] memory hDeltas = [uint256(33), 27, 19, 14, 10, 8, 5, 4, 3];

        width = widths[barIndex];
        height = heights[barIndex];
        hDelta = hDeltas[barIndex];
        pos = long ? 0 : _W;
        for (uint256 i; i < barIndex; ) {
            pos = long ? pos + widths[i] : pos - widths[i];

            unchecked {
                i++;
            }
        }
    }

    function _gradientX(uint256 barIndex, bool long) private pure returns (string memory) {
        string[_BARS] memory longXs = [
            "-1778",
            "-1733.4",
            "-1686.6",
            "-1637.4",
            "-1585.7",
            "-1531.5",
            "-1474.6",
            "-1414.8",
            "-1352"
        ];
        string[_BARS] memory shortXs = [
            "-12373.4",
            "-12328.8",
            "-12281.9",
            "-12232.8",
            "-12181.1",
            "-12126.9",
            "-12069.9",
            "-12010.1",
            "-11947.3"
        ];

        return long ? longXs[barIndex] : shortXs[barIndex];
    }

    function _color(int16 feeRate) private pure returns (string memory) {
        bool long = feeRate > 0;
        uint256 absFeeRate = uint16(feeRate < 0 ? -(feeRate) : feeRate);

        if (absFeeRate >= BPS / 10) {
            // feeRate >= 10%  or feeRate <= -10%
            return long ? "#FFCE94" : "#A0DC50";
        } else if (absFeeRate >= BPS / 100) {
            // 10% > feeRate >= 1% or -1% >= feeRate > -10%
            return long ? "#FFAB5E" : "#82E664";
        } else if (absFeeRate >= BPS / 1000) {
            // 1% > feeRate >= 0.1% or -0.1% >= feeRate > -1%
            return long ? "#FF966E" : "#5ADC8C";
        } else if (absFeeRate >= BPS / 10000) {
            // 0.1% > feeRate >= 0.01% or -0.01% >= feeRate > -0.1%
            return long ? "#FE8264" : "#3CD2AA";
        }
        // feeRate == 0%
        return "#000000";
    }
}
