// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {IChromaticLP} from "@chromatic-protocol/contracts/lp/interfaces/IChromaticLP.sol";
import {IChromaticLPLens} from "@chromatic-protocol/contracts/lp/interfaces/IChromaticLPLens.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FEE_RATES_LENGTH} from "@chromatic-protocol/contracts/core/libraries/Constants.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

uint16 constant BPS = 10000;

contract ChromaticLPLens is IChromaticLPLens {
    using Math for uint256;

    function feeRates() internal pure returns (int16[] memory _feeRates) {
        _feeRates = new int16[](FEE_RATES_LENGTH);
        uint256[] memory clbTokenIds = CLBTokenLib.tokenIds();

        for (uint256 i; i < FEE_RATES_LENGTH; ) {
            _feeRates[i] = CLBTokenLib.decodeId(clbTokenIds[i]);
            unchecked {
                i++;
            }
        }
    }

    function clbTokenBalances(address lp) internal view returns (uint256[] memory balances) {
        uint256[] memory clbTokenIds = CLBTokenLib.tokenIds();
        address[] memory _owners = new address[](clbTokenIds.length);

        for (uint256 i; i < clbTokenIds.length; ) {
            _owners[i] = lp;
            unchecked {
                i++;
            }
        }
        IChromaticMarket market = IChromaticMarket(IChromaticLP(lp).market());

        balances = IERC1155(market.clbToken()).balanceOfBatch(_owners, clbTokenIds);
    }

    function value(address lp) external view override returns (uint256) {
        return holdingValue(lp) + clbValue(lp);
    }

    function clbValue(address lp) public view override returns (uint256 _value) {
        uint256[] memory clbTokenIds = CLBTokenLib.tokenIds();

        IChromaticMarket market = IChromaticMarket(IChromaticLP(lp).market());
        uint256[] memory clbSupplies = market.clbToken().totalSupplyBatch(clbTokenIds);
        uint256[] memory binValues = market.getBinValues(feeRates());
        uint256[] memory clbTokenAmounts = clbTokenBalances(lp);

        for (uint256 i; i < binValues.length; ) {
            _value += clbTokenAmounts[i] == 0
                ? 0
                : clbTokenAmounts[i].mulDiv(binValues[i], clbSupplies[i]);
            unchecked {
                i++;
            }
        }
    }

    function values(
        address lp
    ) public view override returns (uint256 _totalValue, uint256 _clbValue, uint256 _holdingValue) {
        _holdingValue = holdingValue(lp);
        _clbValue = clbValue(lp);
        _totalValue = _holdingValue + _clbValue;
    }

    function holdingValue(address lp) public view override returns (uint256) {
        return IERC20(IChromaticLP(lp).settlementToken()).balanceOf(lp);
    }

    function utilization(address lp) external view override returns (uint256 currentUtility) {
        (uint256 total, uint256 _clbValue, ) = values(lp);
        if (total == 0) return 0;
        currentUtility = _clbValue.mulDiv(BPS, total);
    }
}
