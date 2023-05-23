// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IUSUMLiquidator} from "@usum/core/interfaces/IUSUMLiquidator.sol";
import {IUSUMMarketLiquidate} from "@usum/core/interfaces/market/IUSUMMarketLiquidate.sol";
import {IUSUMMarketFactory} from "@usum/core/interfaces/IUSUMMarketFactory.sol";
import {IAutomate, Module, ModuleData} from "@usum/core/base/gelato/Types.sol";
import 'hardhat/console.sol';
abstract contract Liquidator is IUSUMLiquidator {
    address private constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 private constant LIQUIDATION_INTERVAL = 30 seconds;
    uint256 private constant CLAIM_INTERVAL = 10 minutes;

    IUSUMMarketFactory factory;

    mapping(address => mapping(uint256 => bytes32)) private _liquidationTaskIds;
    mapping(address => mapping(uint256 => bytes32))
        private _claimPositionTaskIds;

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
        _createTask(
            _liquidationTaskIds,
            positionId,
            this.resolveLiquidation,
            LIQUIDATION_INTERVAL
        );
    }

    function cancelLiquidationTask(
        uint256 positionId
    ) external override onlyMarket {
        _cancelTask(_liquidationTaskIds, positionId);
    }

    function resolveLiquidation(
        address _market,
        uint256 positionId
    ) external view override returns (bool canExec, bytes memory execPayload) {
        if (IUSUMMarketLiquidate(_market).checkLiquidation(positionId)) {
            console.log('call liquidate');
            return (
                true,
                abi.encodeCall(this.liquidate, (_market, positionId))
            );
        }

        return (false, bytes(""));
    }

    function _liquidate(
        address _market,
        uint256 positionId,
        uint256 fee
    ) internal {
        IUSUMMarketLiquidate market = IUSUMMarketLiquidate(_market);
        market.liquidate(positionId, getAutomate().gelato(), fee);
    }

    function createClaimPositionTask(
        uint256 positionId
    ) external override onlyMarket {
        _createTask(
            _claimPositionTaskIds,
            positionId,
            this.resolveClaimPosition,
            CLAIM_INTERVAL
        );
    }

    function cancelClaimPositionTask(
        uint256 positionId
    ) external override onlyMarket {
        _cancelTask(_claimPositionTaskIds, positionId);
    }

    function resolveClaimPosition(
        address _market,
        uint256 positionId
    ) external view override returns (bool canExec, bytes memory execPayload) {
        if (IUSUMMarketLiquidate(_market).checkClaimPosition(positionId)) {
            return (
                true,
                abi.encodeCall(this.claimPosition, (_market, positionId))
            );
        }

        return (false, "");
    }

    function _claimPosition(
        address _market,
        uint256 positionId,
        uint256 fee
    ) internal {
        IUSUMMarketLiquidate market = IUSUMMarketLiquidate(_market);
        market.claimPosition(positionId, getAutomate().gelato(), fee);
    }

    function _createTask(
        mapping(address => mapping(uint256 => bytes32)) storage registry,
        uint256 positionId,
        function(address, uint256)
            external
            view
            returns (bool, bytes memory) resolve,
        uint256 interval
    ) internal {
        address market = msg.sender;
        if (registry[market][positionId] != bytes32(0)) {
            return;
        }

        ModuleData memory moduleData = ModuleData({
            modules: new Module[](3),
            args: new bytes[](3)
        });

        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.TIME;
        moduleData.modules[2] = Module.PROXY;
        moduleData.args[0] = abi.encode(
            address(this),
            abi.encodeCall(resolve, (market, positionId))
        );
        moduleData.args[1] = abi.encode(
            uint128(block.timestamp),
            uint128(interval)
        );
        moduleData.args[2] = bytes("");

        registry[market][positionId] = getAutomate().createTask(
            address(this),
            abi.encode(this.liquidate.selector),
            moduleData,
            ETH
        );
    }

    function _cancelTask(
        mapping(address => mapping(uint256 => bytes32)) storage registry,
        uint256 positionId
    ) internal {
        address market = msg.sender;
        bytes32 taskId = registry[market][positionId];
        if (taskId != bytes32(0)) {
            getAutomate().cancelTask(taskId);
            delete registry[market][positionId];
        }
    }
}
