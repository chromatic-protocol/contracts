// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

/**
 * @dev The OracleProviderProperties struct represents properties of the oracle provider.
 * @param minTakeProfitBPS The minimum take-profit basis points.
 * @param maxTakeProfitBPS The maximum take-profit basis points.
 * @param leverageLevel The leverage level of the oracle provider.
 */
struct OracleProviderProperties {
    uint32 minTakeProfitBPS;
    uint32 maxTakeProfitBPS;
    uint8 leverageLevel;
}

using OracleProviderPropertiesLib for OracleProviderProperties global;

library OracleProviderPropertiesLib {
    function checkValidLeverageLevel(uint8 leverageLevel) internal pure returns (bool) {
        return leverageLevel <= 3;
    }

    function maxAllowableLeverage(
        OracleProviderProperties memory self
    ) internal pure returns (uint256 leverage) {
        uint8 level = self.leverageLevel;
        assembly {
            switch level
            case 0 {
                leverage := 10
            }
            case 1 {
                leverage := 20
            }
            case 2 {
                leverage := 50
            }
            case 3 {
                leverage := 100
            }
            default {
                leverage := 0
            }
        }
    }
}
