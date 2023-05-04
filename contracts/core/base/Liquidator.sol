// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IUSUMLiquidator} from "@usum/core/interfaces/IUSUMLiquidator.sol";
import {IUSUMMarketLiquidate} from "@usum/core/interfaces/market/IUSUMMarketLiquidate.sol";
import {IUSUMMarketFactory} from "@usum/core/interfaces/IUSUMMarketFactory.sol";
import {IAutomate, Module, ModuleData} from "@usum/core/base/gelato/Types.sol";

abstract contract Liquidator is IUSUMLiquidator {
    address private constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 private constant LIQUIDATION_INTERVAL = 30 seconds;

    IUSUMMarketFactory factory;

    mapping(address => mapping(uint256 => bytes32)) private _liquidationTaskIds;

    error OnlyAccessableByMarket();

    modifier onlyMarket() {
        if (!factory.isRegisteredMarket(msg.sender))
            revert OnlyAccessableByMarket();
        _;
    }

    constructor(IUSUMMarketFactory _factory) {
        factory = _factory;
    }

    function getAutomate() internal view virtual returns (IAutomate);

    function createLiquidationTask(
        uint256 positionId
    ) external override onlyMarket {
        address market = msg.sender;
        if (_liquidationTaskIds[market][positionId] != bytes32(0)) {
            return;
        }
        ModuleData memory moduleData = ModuleData({
            modules: new Module[](3),
            args: new bytes[](3)
        });

        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.TIME;
        moduleData.modules[2] = Module.PROXY;
        moduleData.args[0] = _resolverModuleArg(
            address(this),
            abi.encodeCall(this.resolveLiquidation, (market, positionId))
        );
        moduleData.args[1] = _timeModuleArg(
            block.timestamp,
            LIQUIDATION_INTERVAL
        );
        moduleData.args[2] = _proxyModuleArg();
        _liquidationTaskIds[market][positionId] = getAutomate().createTask(
            address(this),
            abi.encode(this.liquidate.selector),
            moduleData,
            ETH
        );
    }

    function cancelLiquidationTask(
        uint256 positionId
    ) external override onlyMarket {
        _cancelLiquidationTask(msg.sender, positionId);
    }

    function resolveLiquidation(
        address _market,
        uint256 positionId
    ) external view override returns (bool canExec, bytes memory execPayload) {
        if (IUSUMMarketLiquidate(_market).checkLiquidation(positionId)) {
            return (
                true,
                abi.encodeCall(this.liquidate, (_market, positionId))
            );
        } else {
            return (false, "");
        }
    }

    function _liquidate(
        address _market,
        uint256 positionId,
        uint256 fee
    ) internal {
        IUSUMMarketLiquidate market = IUSUMMarketLiquidate(_market);
        market.liquidate(positionId, getAutomate().gelato(), fee);
    }

    function _cancelLiquidationTask(
        address market,
        uint256 positionId
    ) internal {
        bytes32 taskId = _liquidationTaskIds[market][positionId];
        if (taskId != bytes32(0)) {
            getAutomate().cancelTask(taskId);
            delete _liquidationTaskIds[market][positionId];
        }
    }

    function _resolverModuleArg(
        address _resolverAddress,
        bytes memory _resolverData
    ) internal pure returns (bytes memory) {
        return abi.encode(_resolverAddress, _resolverData);
    }

    function _timeModuleArg(
        uint256 _startTime,
        uint256 _interval
    ) internal pure returns (bytes memory) {
        return abi.encode(uint128(_startTime), uint128(_interval));
    }

    function _proxyModuleArg() internal pure returns (bytes memory) {
        return bytes("");
    }
}
