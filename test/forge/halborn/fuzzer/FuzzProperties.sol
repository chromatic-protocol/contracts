// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./FuzzHelper.sol";

abstract contract FuzzProperties is FuzzHelper{

    function _checkInvariantsAndProperties() internal {
        console.log("_checkInvariantsAndProperties()");
        _inv_vault1();
        _inv_vault2();
        _inv_vault3();
        _inv_vault4();
        _inv_market1();
        _inv_market2();
        _inv_market3();
        line = "INVARIANTS_OK";
        vm.writeLine(path, line);
    }

    /**
        ERC20(settlementToken).balanceOf(ChromaticVault) 
        = 
        ChromaticVault.makerBalances(settlementToken) 
        + 
        ChromaticVault.takerBalances(settlementToken) 
        + 
        ChromaticVault.pendingDeposits(settlementToken) 
        + 
        ChromaticVault.pendingWithdrawals(settlementToken) 
        + 
        ChromaticVault.pendingMakerEarnings(settlementToken)
    */
    function _inv_vault1() internal {
        console.log("_inv_vault1()");
        uint256 settlementVaultBalance = contract_TestSettlementToken.balanceOf(address(contract_ChromaticVault));
        uint256 sum = 
            contract_ChromaticVault.makerBalances(address(contract_TestSettlementToken)) +
            contract_ChromaticVault.takerBalances(address(contract_TestSettlementToken)) +
            contract_ChromaticVault.pendingDeposits(address(contract_TestSettlementToken)) +
            contract_ChromaticVault.pendingWithdrawals(address(contract_TestSettlementToken)) +
            contract_ChromaticVault.pendingMakerEarnings(address(contract_TestSettlementToken));
        if(settlementVaultBalance != sum){
            if (enableDebugToFile){
                line = string.concat(
                    "INVARIANT_VIOLATED;TimeStamp(",
                    Strings.toString(block.timestamp),
                    ");SettlementVaultBalance(",
                    Strings.toString(settlementVaultBalance),
                    ");Sum(",
                    Strings.toString(sum),
                    ");Invariant(_inv_vault1())"
                );
                vm.writeLine(path, line);
            }
            revert("Invariant: _inv_vault1() violated");
        }
    }

    /**
        ChromaticVault.makerBalances(settlementToken) == SUM(ChromaticVault.makerMarketBalances(markets[i]))
    */
    function _inv_vault2() internal {
        console.log("_inv_vault2()");
        uint256 makerBalances = contract_ChromaticVault.makerBalances(address(contract_TestSettlementToken));
        address[] memory _markets = contract_ChromaticMarketFactory.getMarketsBySettlmentToken(address(contract_TestSettlementToken));
        uint256 sum;
        for(uint256 i; i < _markets.length; ++i){
            sum += contract_ChromaticVault.makerMarketBalances(_markets[i]);
        }
        if(makerBalances != sum){
            if (enableDebugToFile){
                line = string.concat(
                    "INVARIANT_VIOLATED;TimeStamp(",
                    Strings.toString(block.timestamp),
                    ");MakerBalances(",
                    Strings.toString(makerBalances),
                    ");Sum(",
                    Strings.toString(sum),
                    ");Invariant(_inv_vault2())"
                );
                vm.writeLine(path, line);
            }
            revert("Invariant: _inv_vault2() violated");
        }
    }

    /**
        ChromaticVault.takerBalances(settlementToken) == SUM(ChromaticVault.takerMarketBalances(markets[i]))
    */
    function _inv_vault3() internal {
        console.log("_inv_vault3()");
        uint256 takerBalances = contract_ChromaticVault.takerBalances(address(contract_TestSettlementToken));
        address[] memory _markets = contract_ChromaticMarketFactory.getMarketsBySettlmentToken(address(contract_TestSettlementToken));
        uint256 sum;
        for(uint256 i; i < _markets.length; ++i){
            sum += contract_ChromaticVault.takerMarketBalances(_markets[i]);
        }
        if(takerBalances != sum){
            if (enableDebugToFile){
                line = string.concat(
                    "INVARIANT_VIOLATED;TimeStamp(",
                    Strings.toString(block.timestamp),
                    ");TakerBalances(",
                    Strings.toString(takerBalances),
                    ");Sum(",
                    Strings.toString(sum),
                    ");Invariant(_inv_vault3())"
                );
                vm.writeLine(path, line);
            }
            revert("Invariant: _inv_vault3() violated");
        }
    }

    /**
        ChromaticVault.pendingMakerEarnings(settlementToken) == SUM(ChromaticVault.pendingMarketEarnings(markets[i]))
    */
    function _inv_vault4() internal {
        console.log("_inv_vault4()");
        uint256 pendingMakerEarnings = contract_ChromaticVault.pendingMakerEarnings(address(contract_TestSettlementToken));
        address[] memory _markets = contract_ChromaticMarketFactory.getMarketsBySettlmentToken(address(contract_TestSettlementToken));
        uint256 sum;
        for(uint256 i; i < _markets.length; ++i){
            sum += contract_ChromaticVault.pendingMarketEarnings(_markets[i]);
        }
        if(pendingMakerEarnings != sum){
            if (enableDebugToFile){
                line = string.concat(
                    "INVARIANT_VIOLATED;TimeStamp(",
                    Strings.toString(block.timestamp),
                    ");MakerEarnings(",
                    Strings.toString(pendingMakerEarnings),
                    ");Sum(",
                    Strings.toString(sum),
                    ");Invariant(_inv_vault3())"
                );
                vm.writeLine(path, line);
            }
            revert("Invariant: _inv_vault3() violated");
        }
    }

    /**
        ChromaticVault.makerMarketBalances(markets[i]) == SUM(ChromaticMarket(markets[i]).liquidityBinStatuses()[j].liquidity)
    */
    function _inv_market1() internal {
        console.log("_inv_market1()");

        address[] memory _markets = contract_ChromaticMarketFactory.getMarketsBySettlmentToken(address(contract_TestSettlementToken));
        uint256 sum;
        uint256 sumLiqBins;
        for(uint256 i; i < _markets.length; ++i){
            sum += contract_ChromaticVault.makerMarketBalances(_markets[i]);
        }

        for(uint256 i; i < _markets.length; ++i){
            LiquidityBinStatus[] memory statuses = MarketLensFacet(_markets[i]).liquidityBinStatuses();
            for(uint256 j; j < statuses.length; ++j){
                sumLiqBins += statuses[j].liquidity;
            }
        }
        if(sum != sumLiqBins){
            if (enableDebugToFile){
                line = string.concat(
                    "INVARIANT_VIOLATED;TimeStamp(",
                    Strings.toString(block.timestamp),
                    ");MakerMarketBalances(",
                    Strings.toString(sum),
                    ");SumLiquidityBins(",
                    Strings.toString(sumLiqBins),
                    ");Invariant(_inv_market1())"
                );
                vm.writeLine(path, line);
            }
            revert("Invariant: _inv_market1() violated");
        }
    }

    /**
        ChromaticVault.takerMarketBalances(markets[i]) = SUM(ChromaticMarket(markets[i]).getPositions(<all position ids>)[j].takerMargin)
    */
    function _inv_market2() internal {
        console.log("_inv_market2()");

        address[] memory _markets = contract_ChromaticMarketFactory.getMarketsBySettlmentToken(address(contract_TestSettlementToken));
        uint256 sum;
        uint256 sumMargins;
        for(uint256 i; i < _markets.length; ++i){
            sum += contract_ChromaticVault.takerMarketBalances(_markets[i]);
        }
        for(uint256 j; j < state_positionsSinceDay0.length; ++j){
            try MarketLensFacet(address(contract_ChromaticMarket)).getPosition(state_positionsSinceDay0[j])returns(Position memory position){
                sumMargins += position.takerMargin;
            } catch{}
        }
        if(sum != sumMargins){
            if (enableDebugToFile){
                line = string.concat(
                    "INVARIANT_VIOLATED;TimeStamp(",
                    Strings.toString(block.timestamp),
                    ");TakerMarketBalances(",
                    Strings.toString(sum),
                    ");SumTakerMargins(",
                    Strings.toString(sumMargins),
                    ");Invariant(_inv_market2())"
                );
                vm.writeLine(path, line);
            }
            revert("Invariant: _inv_market2() violated");
        }
    }

    /**
        ChromaticVault.pendingDeposits(settlementToken) = SUM(ChromaticMarket(markets[i]).pendingLiquidityBatch(<all fee rates>)[j].mintingTokenAmountRequested)
    */
    function _inv_market3() internal {
        console.log("_inv_market3()");

        address[] memory _markets = contract_ChromaticMarketFactory.getMarketsBySettlmentToken(address(contract_TestSettlementToken));
        uint256 pendingDeposits = contract_ChromaticVault.pendingDeposits(address(contract_TestSettlementToken));
        uint256 sum;
        for(uint256 i; i < _markets.length; ++i){
            int16[] memory _allFees = allFeeRates;
            PendingLiquidity[] memory liquidities = MarketLensFacet(_markets[i]).pendingLiquidityBatch(_allFees);
            for(uint256 j; j < liquidities.length; ++j){
                sum += liquidities[j].mintingTokenAmountRequested;
            }
        }
        if(sum != pendingDeposits){
            if (enableDebugToFile){
                line = string.concat(
                    "INVARIANT_VIOLATED;TimeStamp(",
                    Strings.toString(block.timestamp),
                    ");PendingDeposits(",
                    Strings.toString(pendingDeposits),
                    ");SumMintingTokenAmountRequested(",
                    Strings.toString(sum),
                    ");Invariant(_inv_market3())"
                );
                vm.writeLine(path, line);
            }
            revert("Invariant: _inv_market3() violated");
        }
    }
}