// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./FuzzStorage.sol";

abstract contract FuzzHelper is FuzzStorage {
    using Strings for *;

    // This is our "real" setUp function.
    function setUpEnvTests() public {
        console.log("setUpEnvTests()");
        _setupLogPath();
        // All the project is deployed
        _deployAll();
        // We generate correct fuzzing input
        _assumeValidState();
        // Deal some SettlementTokens to users
        _dealUsers();
        // Create one account per user
        _createAccounts();
        // Init allFeeRates array with the 72 fees
        _initFeeRatesArray();
    }

    function _setupLogPath() internal {
        console.log("_setupLogPath()");
        string memory id = vm.readFile(initPath);
        uint256 newId = stringToUint(id) + 1;
        path = string.concat(
            "./test/forge/halborn/fuzzer/logs/debug_",
            Strings.toString(newId),
            ".txt"
        );
        vm.removeFile(initPath);
        vm.writeFile(initPath, Strings.toString(newId));
    }

    /**
        Filter out some non-conforming input
            1. Private keys should be unique, this way we make sure there is no repeated user in the system
    */
    function _assumeValidState() internal {
        console.log("_assumeValidState()");
        // Owner/deployer PK
        PK_used[100] = true;
        uint256 iteration = 0;
        if (enableDebugToFile) {
            line = "___________________________________________";
            vm.writeLine(path, line);
            line = string.concat(
                "BlockTimestamp(",
                Strings.toString(block.timestamp),
                ");BlockNumber(",
                Strings.toString(block.number),
                ")"
            );
            vm.writeLine(path, line);
            line = "___________________________________________";
            vm.writeLine(path, line);
        }
        address user;
        uint256 privateKey;
        for (uint256 i; i < MAKERS; ++i) {
            privateKey = bound(
                contract_FuzzRandomizer.getRandomNumber(),
                1000,
                1157920892373161954235709850086879078528375642790749043826051631415181614
            );
            if (PK_used[privateKey]) {
                vm.writeLine(path, "EXECUTION CANCELED: PK_used[privateKey]");
            }
            vm.assume(!PK_used[privateKey]);
            PK_used[privateKey] = true;
            user = vm.addr(privateKey);
            state_makers.push(user);
            state_PrivateKeys[user] = privateKey;
            /**
                Note: Random
                SETTLEMENT TOKEN INITIAL AMOUNT DEALT 
                The initial SETTLEMENT TOKEN amount those users will have is between LOW_THRESHOLD_ST_MAKER_BALANCE and HIGH_THRESHOLD_ST_MAKER_BALANCE
            */
            state_initialBalances[user][address(contract_TestSettlementToken)] = bound(
                contract_FuzzRandomizer.getRandomNumber(),
                LOW_THRESHOLD_ST_MAKER_BALANCE,
                HIGH_THRESHOLD_ST_MAKER_BALANCE
            );

            iteration++;
            emit DebugStateCreated(
                iteration,
                user,
                privateKey,
                state_initialBalances[user][address(contract_TestSettlementToken)],
                block.timestamp
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "StateCreated;Id(",
                    Strings.toString(iteration),
                    ");Maker(",
                    Strings.toHexString(uint160(user), 20),
                    ");PrivateKey(",
                    Strings.toString(privateKey),
                    ");InitialSettlementTokenBalance(",
                    Strings.toString(
                        state_initialBalances[user][address(contract_TestSettlementToken)]
                    ),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    ")"
                );
                vm.writeLine(path, line);
            }
        }
        for (uint256 i; i < TAKERS; ++i) {
            privateKey = bound(
                contract_FuzzRandomizer.getRandomNumber(),
                1000,
                1157920892373161954235709850086879078528375642790749043826051631415181614
            );
            if (PK_used[privateKey]) {
                vm.writeLine(path, "EXECUTION CANCELED: PK_used[privateKey]");
            }
            vm.assume(!PK_used[privateKey]);
            PK_used[privateKey] = true;
            user = vm.addr(privateKey);
            state_takers.push(user);
            state_PrivateKeys[user] = privateKey;
            /**
                Note: Random
                SETTLEMENT TOKEN INITIAL AMOUNT DEALT 
                The initial SETTLEMENT TOKEN amount those users will have is between LOW_THRESHOLD_ST_TAKER_BALANCE and HIGH_THRESHOLD_ST_TAKER_BALANCE
            */
            state_initialBalances[user][address(contract_TestSettlementToken)] = bound(
                contract_FuzzRandomizer.getRandomNumber(),
                LOW_THRESHOLD_ST_TAKER_BALANCE,
                HIGH_THRESHOLD_ST_TAKER_BALANCE
            );

            iteration++;
            emit DebugStateCreated(
                iteration,
                user,
                privateKey,
                state_initialBalances[user][address(contract_TestSettlementToken)],
                block.timestamp
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "StateCreated;Id(",
                    Strings.toString(iteration),
                    ");Taker(",
                    Strings.toHexString(uint160(user), 20),
                    ");PrivateKey(",
                    Strings.toString(privateKey),
                    ");InitialSettlementTokenBalance(",
                    Strings.toString(
                        state_initialBalances[user][address(contract_TestSettlementToken)]
                    ),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    ")"
                );
                vm.writeLine(path, line);
            }
        }
    }

    function _deployAll() internal {
        // UNCOMMENT TO ENABLE FORKING V
        // ARB_FORK_ID = vm.createFork(ARB_RPC_URL, 173394920); // 23/01/2024 16:17
        // vm.selectFork(ARB_FORK_ID);
        // UNCOMMENT TO ENABLE FORKING ^
        contract_FuzzRandomizer = new FuzzRandomizer();
        uint256 entropyUsed = contract_FuzzRandomizer.getCurrentRandomNumber();
        if (enableDebugToFile) {
            line = string.concat("ENTROPY(", Strings.toString(entropyUsed), ")");
            vm.writeLine(path, line);
        }

        vm.mockCall(
            address(_automate),
            abi.encodeWithSelector(_automate.getFeeDetails.selector),
            abi.encode(0, address(_automate))
        );
        vm.mockCall(
            address(_automate),
            abi.encodeWithSelector(_automate.gelato.selector),
            abi.encode(address(_automate))
        );
        vm.mockCall(
            address(_automate),
            abi.encodeWithSelector(IGelato(address(_automate)).feeCollector.selector),
            abi.encode(address(_automate))
        );
        vm.mockCall(
            address(_automate),
            abi.encodeWithSelector(_automate.taskModuleAddresses.selector),
            abi.encode(address(_automate))
        );
        vm.mockCall(
            address(_automate),
            abi.encodeWithSelector(IProxyModule(address(_automate)).opsProxyFactory.selector),
            abi.encode(address(_automate))
        );
        vm.mockCall(
            address(_automate),
            abi.encodeWithSelector(IOpsProxyFactory(address(_automate)).getProxyOf.selector),
            abi.encode(address(_automate), true)
        );
        vm.mockCall(
            address(_automate),
            abi.encodeWithSelector(_automate.createTask.selector),
            abi.encode(bytes32(""))
        );

        vm.startPrank(owner, owner);
        contract_MarketDiamondCutFacet = new MarketDiamondCutFacet();
        contract_DiamondLoupeFacet = new DiamondLoupeFacet();
        contract_MarketStateFacet = new MarketStateFacet();
        contract_MarketAddLiquidityFacet = new MarketAddLiquidityFacet();
        contract_MarketRemoveLiquidityFacet = new MarketRemoveLiquidityFacet();
        contract_MarketLensFacet = new MarketLensFacet();
        contract_MarketTradeOpenPositionFacet = new MarketTradeOpenPositionFacet();
        contract_MarketTradeClosePositionFacet = new MarketTradeClosePositionFacet();
        contract_MarketLiquidateFacet = new MarketLiquidateFacet();
        contract_MarketSettleFacet = new MarketSettleFacet();

        /**
            ChromaticMarketFactory:
            constructor(
                address _marketDiamondCutFacet,
                address _marketLoupeFacet,
                address _marketStateFacet,
                address _marketLiquidityFacet,
                address _marketLiquidityLensFacet,
                address _marketTradeFacet,
                address _marketLiquidateFacet,
                address _marketSettleFacet
            ) 
        */
        contract_ChromaticMarketFactory = new ChromaticMarketFactory(
            address(contract_MarketDiamondCutFacet),
            address(contract_DiamondLoupeFacet),
            address(contract_MarketStateFacet),
            address(contract_MarketAddLiquidityFacet),
            address(contract_MarketRemoveLiquidityFacet),
            address(contract_MarketLensFacet),
            address(contract_MarketTradeOpenPositionFacet),
            address(contract_MarketTradeClosePositionFacet),
            address(contract_MarketLiquidateFacet),
            address(contract_MarketSettleFacet)
        );

        /**
            GelatoVaultEarningDistributor:
            constructor(
                IChromaticMarketFactory _factory,
                address _automate
            ) 
        */
        contract_GelatoVaultEarningDistributor = new GelatoVaultEarningDistributor(
            IChromaticMarketFactory(address(contract_ChromaticMarketFactory)),
            address(_automate)
        );

        /**
            ChromaticVault:
            constructor(IChromaticMarketFactory _factory, IVaultEarningDistributor _earningDistributor)
        */
        contract_ChromaticVault = new ChromaticVault(
            IChromaticMarketFactory(address(contract_ChromaticMarketFactory)),
            IVaultEarningDistributor(address(contract_GelatoVaultEarningDistributor))
        );

        /**
            ChromaticRouter:
            constructor(address _marketFactory) AccountFactory(_marketFactory) 
        */
        contract_ChromaticRouter = new ChromaticRouter(address(contract_ChromaticMarketFactory));

        /**
            ChromaticLens:
            constructor(IChromaticRouter _router)
        */
        contract_ChromaticLens = new ChromaticLens(
            IChromaticRouter(address(contract_ChromaticRouter))
        );

        /**
            KeeperFeePayer:
            constructor(IChromaticMarketFactory _factory, ISwapRouter _uniswapRouter, IWETH9 _weth)
        */
        contract_KeeperFeePayer = new KeeperFeePayer(
            IChromaticMarketFactory(address(contract_ChromaticMarketFactory)),
            ISwapRouter(UNISWAPV3),
            IWETH9(address(contract_WETH))
        );

        contract_ChromaticMarketFactory.updateKeeperFeePayer(address(contract_KeeperFeePayer));
        contract_ChromaticMarketFactory.setVault(address(contract_ChromaticVault));

        /**
            GelatoLiquidator:
            constructor(
                IChromaticMarketFactory _factory,
                address _automate
            ) LiquidatorBase(_factory) AutomateReady(_automate, address(this)) 
        */
        contract_GelatoLiquidator = new GelatoLiquidator(
            IChromaticMarketFactory(address(contract_ChromaticMarketFactory)),
            address(_automate)
        );
        contract_ChromaticMarketFactory.updateLiquidator(address(contract_GelatoLiquidator));

        /**
            PriceFeedMock:
            constructor()
        */
        contract_PriceFeedMock = new PriceFeedMock();
        contract_PriceFeedMock.setRoundData(1e18);

        /**
            ChainlinkFeedOracle:
            constructor(ChainlinkAggregator aggregator_)
        */
        contract_ChainlinkFeedOracle = new ChainlinkFeedOracle(
            ChainlinkAggregator.wrap(address(contract_PriceFeedMock))
        );

        contract_ChromaticMarketFactory.registerOracleProvider(
            address(address(contract_ChainlinkFeedOracle)),
            OracleProviderProperties({
                minTakeProfitBPS: 1000, // 10%
                maxTakeProfitBPS: 100000, // 1000%
                leverageLevel: 0
            })
        );

        /**
            TestSettlementToken:
            constructor(
                string memory name_,
                string memory symbol_,
                uint256 faucetAmount_,
                uint256 faucetMinInterval_
            ) ERC20("", "")
        */
        contract_TestSettlementToken = new TestSettlementToken("", "", 1000000e18, 86400);

        contract_ChromaticMarketFactory.registerSettlementToken(
            address(contract_TestSettlementToken),
            address(contract_ChainlinkFeedOracle), // oracleProvider
            1 ether, // minimumMargin
            1000, // interestRate, 10%
            500, // flashLoanFeeRate, 5%
            10 ether, // earningDistributionThreshold, $10
            3000 // uniswapFeeRate, 0.3%
        );

        contract_ChromaticMarketFactory.createMarket(
            address(contract_ChainlinkFeedOracle),
            address(contract_TestSettlementToken)
        );
        contract_ChromaticMarket = ChromaticMarket(
            payable(contract_ChromaticMarketFactory.getMarkets()[0])
        );
        contract_CLBToken = CLBToken(
            address(IChromaticMarket(address(contract_ChromaticMarket)).clbToken())
        );

        /**
            Mate2Liquidator
            constructor(IChromaticMarketFactory _factory, address _automate)
        */
        contract_Mate2Liquidator = new Mate2Liquidator(
            IChromaticMarketFactory(contract_ChromaticMarketFactory),
            address(_automate)
        );

        contract_PriceFeedMock.setRoundData(1e18);
        vm.stopPrank();
    }

    function _dealUsers() internal {
        address _user;
        for (uint256 i; i < state_makers.length; ++i) {
            _user = state_makers[i];
            deal(
                address(contract_TestSettlementToken),
                _user,
                state_initialBalances[_user][address(contract_TestSettlementToken)]
            );
        }
        for (uint256 i; i < state_takers.length; ++i) {
            _user = state_takers[i];
            deal(
                address(contract_TestSettlementToken),
                _user,
                state_initialBalances[_user][address(contract_TestSettlementToken)]
            );
        }
    }

    function _createAccounts() internal {
        address _user;
        for (uint256 i; i < state_takers.length; ++i) {
            _user = state_takers[i];
            vm.startPrank(_user, _user);
            contract_ChromaticRouter.createAccount();
            contract_TestSettlementToken.transfer(
                contract_ChromaticRouter.getAccount(),
                contract_TestSettlementToken.balanceOf(_user)
            );
            vm.stopPrank();
        }
    }

    /**
        Actions that are done every time a new state is entered:
            1. Advance between 1 and 7 days
            2. _alterPrice(0, 700);
            3. Liquidate whoever can be liquidated
            4. SettleAll
    */
    function _endStateActions() internal {
        console.log("_endStateActions()");
        vm.writeLine(path, "ENTERED_ENDSTATE");
        // 1. Advance between 1 and 7 days
        uint256 secsToWarp = bound(contract_FuzzRandomizer.getRandomNumber(), 1 days, 7 days);
        vm.warp(block.timestamp + secsToWarp);
        vm.roll(block.number + (secsToWarp / 12));
        // 2. _alterPrice(0, 700);
        _alterPrice(0, 700);
        // 3. Liquidate/claim whoever possible
        _liquidateAndClaimIfPossible();
        // 4. SettleAll()
        vm.startPrank(owner, owner);
        MarketSettleFacet(address(contract_ChromaticMarket)).settleAll();
        vm.stopPrank();
    }

    /* 
        Admin actions:
            1. TODO
    */
    function _adminAction(uint256 _option) internal {
        console.log("_adminAction()");
    }

    function stringToUint(string memory s) public pure returns (uint) {
        bytes memory b = bytes(s);
        uint result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
    }

    function encodeId(int16 tradingFeeRate) internal pure returns (uint256) {
        bool long = tradingFeeRate > 0;
        return _encodeId(uint16(long ? tradingFeeRate : -tradingFeeRate), long);
    }

    function _encodeId(uint16 tradingFeeRate, bool long) private pure returns (uint256 id) {
        id = long ? tradingFeeRate : tradingFeeRate + (10 ** 10);
    }

    function _initFeeRatesArray() internal {
        LiquidityBinStatus[] memory statuses = MarketLensFacet(address(contract_ChromaticMarket))
            .liquidityBinStatuses();
        for (uint256 j; j < statuses.length; ++j) {
            allFeeRates.push(statuses[j].tradingFeeRate);
        }
    }

    /**
        1. addLiquidity
        2. removeLiquidity
        3. withdrawLiquidity
        4. claimLiquidity
        5. addLiquidityBatch
        6. claimLiquidityBatch
        7. removeLiquidityBatch
        8. withdrawLiquidityBatch
    */
    function _executeMakerAction(
        address _user,
        uint256 _selection,
        uint256 _iterationNumber
    ) internal {
        // If we are starting up the fuzzer
        if (_iterationNumber == 0) {
            wrapper_addLiquidity(_user);
        } else {
            if (_selection == 0) {
                wrapper_addLiquidity(_user);
            }
            if (_selection == 1) {
                wrapper_removeLiquidity(_user);
            }
            if (_selection == 2) {
                wrapper_claimLiquidity(_user);
            }
        }
        // Between 0 and 1% price variation
        _alterPrice(0, 100);
    }

    /**
        1. openPosition
        2. closePosition
        3. claimPosition
    */
    function _executeTakerAction(
        address _user,
        uint256 _selection,
        uint256 _iterationNumber
    ) internal {
        // If we are starting up the fuzzer
        if (_iterationNumber == 0) {
            wrapper_openPosition(_user);
        } else {
            if (_selection == 0) {
                wrapper_openPosition(_user);
            }
            if (_selection == 1) {
                wrapper_closePosition(_user);
            }
            if (_selection == 2) {
                wrapper_claimPosition(_user);
            }
            if (_selection == 3) {
                wrapper_withdrawLiquidity(_user);
            }
        }
        // Between 0 and 1% price variation
        _alterPrice(0, 100);
    }

    function _liquidateAndClaimIfPossible() internal {
        address _user;
        uint256 _posId;
        uint256 len;
        vm.startPrank(address(contract_GelatoLiquidator), address(contract_GelatoLiquidator));
        for (uint256 i; i < state_takers.length; ++i) {
            _user = state_takers[i];
            // CLAIMABLE ARRAY
            len = state_claimablePositions[_user].length;
            uint256[] memory array = state_claimablePositions[_user];
            for (uint256 j; j < array.length; ++j) {
                _posId = array[j];
                if (
                    MarketLiquidateFacet(address(contract_ChromaticMarket)).checkClaimPosition(
                        _posId
                    )
                ) {
                    // Reorder original array
                    for (uint256 k; k < state_claimablePositions[_user].length; ++k) {
                        if (state_claimablePositions[_user][k] == _posId) {
                            state_claimablePositions[_user][k] = state_claimablePositions[_user][
                                state_claimablePositions[_user].length - 1
                            ];
                            state_claimablePositions[_user].pop();
                            break;
                        }
                    }
                    // Execute claim position
                    MarketLiquidateFacet(address(contract_ChromaticMarket)).claimPosition(
                        _posId,
                        address(_automate),
                        0
                    );
                    if (enableDebugToFile) {
                        line = string.concat(
                            "AutomaticClaim;User(",
                            Strings.toHexString(uint160(_user), 20),
                            ");PositionId(",
                            Strings.toString(_posId),
                            ");TimeStamp(",
                            Strings.toString(block.timestamp),
                            ")"
                        );
                        vm.writeLine(path, line);
                    }
                }
            }
            // OPENED POSITION ARRAY
            len = state_openedPositions[_user].length;
            uint256[] memory array2 = state_openedPositions[_user];
            for (uint256 j; j < array2.length; ++j) {
                _posId = array2[j];
                if (
                    MarketLiquidateFacet(address(contract_ChromaticMarket)).checkLiquidation(_posId)
                ) {
                    // Reorder original array
                    for (uint256 k; k < state_openedPositions[_user].length; ++k) {
                        if (state_openedPositions[_user][k] == _posId) {
                            state_openedPositions[_user][k] = state_openedPositions[_user][
                                state_openedPositions[_user].length - 1
                            ];
                            state_openedPositions[_user].pop();
                            break;
                        }
                    }
                    // Execute the liquidation of the position
                    MarketLiquidateFacet(address(contract_ChromaticMarket)).liquidate(
                        _posId,
                        address(_automate),
                        0
                    );
                    if (enableDebugToFile) {
                        line = string.concat(
                            "AutomaticLiquidation;User(",
                            Strings.toHexString(uint160(_user), 20),
                            ");PositionId(",
                            Strings.toString(_posId),
                            ");TimeStamp(",
                            Strings.toString(block.timestamp),
                            ")"
                        );
                        vm.writeLine(path, line);
                    }
                }
            }
        }
        vm.stopPrank();
    }

    function _alterPrice(uint256 _minPercentage, uint256 _maxPercentage) internal {
        // 1. Oracle prices fluctuate for the SettlementToken
        uint256 raisePrice = contract_FuzzRandomizer.getRandomNumber() % 2;
        // 0 to 5% price variation
        uint256 priceVariation = bound(
            contract_FuzzRandomizer.getRandomNumber(),
            _minPercentage,
            _maxPercentage
        );
        uint256 priceBefore = currentOraclePrice;
        if (raisePrice == 0) {
            // 50% chance of price increased
            currentOraclePrice =
                currentOraclePrice +
                ((currentOraclePrice * priceVariation) / 10000);
            contract_PriceFeedMock.setRoundData(int256(currentOraclePrice));
            if (enableDebugToFile) {
                line = string.concat(
                    "PriceIncreased;Ratio(",
                    Strings.toString(priceVariation),
                    ");PriceBefore(",
                    Strings.toString(priceBefore),
                    ");PriceNow(",
                    Strings.toString(currentOraclePrice),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    ")"
                );
                vm.writeLine(path, line);
            }
        } else {
            // 50% chance of price decreased
            currentOraclePrice =
                currentOraclePrice -
                ((currentOraclePrice * priceVariation) / 10000);
            contract_PriceFeedMock.setRoundData(int256(currentOraclePrice));
            if (enableDebugToFile) {
                line = string.concat(
                    "PriceDecreased;Ratio(",
                    Strings.toString(priceVariation),
                    ");PriceBefore(",
                    Strings.toString(priceBefore),
                    ");PriceNow(",
                    Strings.toString(currentOraclePrice),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    ")"
                );
                vm.writeLine(path, line);
            }
        }
    }

    function wrapper_openPosition(address _user) internal {
        /**
            function openPosition(
                address market,
                int256 qty,
                uint256 takerMargin,
                uint256 makerMargin,
                uint256 maxAllowableTradingFee
            ) external override returns (OpenPositionInfo memory)
        */
        /**
            Random parameters:
            1. Long / short
            2. Collateral Amount
            3. Leverage: 1x - 10x
            4. Take Profit: 10% to 1000%
        */
        uint256 randomness;
        bool isLong;
        randomness = contract_FuzzRandomizer.getRandomNumber() % 2;
        if (randomness == 0) {
            isLong = true;
        }
        vm.startPrank(_user, _user);
        ChromaticAccount contract_userChromaticAccount = ChromaticAccount(
            contract_ChromaticRouter.getAccount()
        );
        uint256 _userBalance = contract_TestSettlementToken.balanceOf(
            address(contract_userChromaticAccount)
        );
        uint256 collateralAmount = bound(
            contract_FuzzRandomizer.getRandomNumber(),
            _userBalance / 4,
            _userBalance / 2
        );
        uint256 leverage = (contract_FuzzRandomizer.getRandomNumber() % 10) + 1;
        int256 _qty = int256(collateralAmount) * int256(leverage);
        if (!isLong) {
            _qty = -_qty;
        }
        uint256 takeProfit = bound(contract_FuzzRandomizer.getRandomNumber(), 1000, 100000); // 1000 = 10%, 100000 = 1000%

        try
            contract_ChromaticRouter.openPosition(
                address(contract_ChromaticMarket),
                _qty, // QTY: collateral * leverage
                collateralAmount, // Taker margin: collateral
                (collateralAmount * leverage * takeProfit) / 10000, // Maker margin: collateral * leverage * take profit%
                type(uint256).max // 100%
            )
        returns (OpenPositionInfo memory _openPosInfo) {
            state_openedPositions[_user].push(_openPosInfo.id);
            state_positionsSinceDay0.push(_openPosInfo.id);
            emit DebugPositionOpened(
                _user,
                _openPosInfo.id,
                _qty,
                collateralAmount,
                (collateralAmount * leverage * takeProfit) / 10000,
                block.timestamp
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "PositionOpened;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");Id(",
                    Strings.toString(_openPosInfo.id),
                    ");Long(",
                    vm.toString(isLong),
                    ");QTY(",
                    Strings.toString(collateralAmount * leverage),
                    ");TakerMargin(",
                    Strings.toString(collateralAmount),
                    ");MakerMargin(",
                    Strings.toString((collateralAmount * leverage * takeProfit) / 10000),
                    ");Leverage(",
                    Strings.toString(leverage),
                    ");TakeProfit(",
                    Strings.toString(takeProfit),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    ")"
                );
                vm.writeLine(path, line);
            }
        } catch Error(string memory revertReason) {
            emit DebugPositionOpenedFailed(
                _user,
                block.timestamp,
                string.concat("PositionOpenedFailed:", revertReason)
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "PositionOpenedFailed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    string.concat(");Reason(", revertReason),
                    ")"
                );
                vm.writeLine(path, line);
            }
        } catch (bytes memory returnData) {
            emit DebugPositionOpenedFailed(
                _user,
                block.timestamp,
                string.concat("PositionOpenedFailed:", vm.toString(returnData))
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "PositionOpenedFailed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    string.concat(");Reason(", vm.toString(returnData)),
                    ")"
                );
                vm.writeLine(path, line);
            }
        }
        vm.stopPrank();
    }

    function wrapper_closePosition(address _user) internal {
        /**
            function closePosition(address market, uint256 positionId) external override
        */
        /**
            Random parameters:
            1. Which position to close (if any)
        */
        uint256 positionsOpened = state_openedPositions[_user].length;
        if (positionsOpened == 0) {
            emit DebugPositionClosedFailed(
                _user,
                block.timestamp,
                string.concat("PositionClosedFailed:", "NO_POS_OPENED")
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "PositionClosedFailed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    string.concat(");Reason(NO_POS_OPENED)")
                );
                vm.writeLine(path, line);
            }
            return;
        }
        uint256 selection = contract_FuzzRandomizer.getRandomNumber() % positionsOpened;
        uint256 posId = state_openedPositions[_user][selection];
        vm.startPrank(_user, _user);
        try contract_ChromaticRouter.closePosition(address(contract_ChromaticMarket), posId) {
            // Remove position from state_openedPositions[_user] array
            state_openedPositions[_user][selection] = state_openedPositions[_user][
                state_openedPositions[_user].length - 1
            ];
            state_openedPositions[_user].pop();
            emit DebugPositionClosed(_user, posId, block.timestamp);
            if (enableDebugToFile) {
                line = string.concat(
                    "PositionClosed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");Id(",
                    Strings.toString(posId),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    ")"
                );
                vm.writeLine(path, line);
            }
            state_claimablePositions[_user].push(posId);
        } catch Error(string memory revertReason) {
            emit DebugPositionClosedFailed(
                _user,
                block.timestamp,
                string.concat("PositionClosedFailed:", revertReason)
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "PositionClosedFailed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    string.concat(");Reason(", revertReason),
                    ")"
                );
                vm.writeLine(path, line);
            }
        } catch (bytes memory returnData) {
            emit DebugPositionClosedFailed(
                _user,
                block.timestamp,
                string.concat("PositionClosedFailed:", vm.toString(returnData))
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "PositionClosedFailed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    string.concat(");Reason(", vm.toString(returnData)),
                    ")"
                );
                vm.writeLine(path, line);
            }
        }
        vm.stopPrank();
    }

    function wrapper_claimPosition(address _user) internal {
        /**
            function claimPosition(address market, uint256 positionId) external override 
        */
        /**
            Random parameters:
            1. Which position to claim (if any)
        */
        uint256 claimablePositions = state_claimablePositions[_user].length;
        if (claimablePositions == 0) {
            emit DebugPositionClaimedFailed(
                _user,
                block.timestamp,
                string.concat("PositionClaimedFailed:", "NO_CLAIMABLE_POS")
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "PositionClaimedFailed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    string.concat(");Reason(NO_CLAIMABLE_POS)")
                );
                vm.writeLine(path, line);
            }
            return;
        }
        uint256 selection = contract_FuzzRandomizer.getRandomNumber() % claimablePositions;
        uint256 _positionId = state_claimablePositions[_user][selection];
        vm.startPrank(_user, _user);
        try contract_ChromaticRouter.claimPosition(address(contract_ChromaticMarket), _positionId) {
            // Remove position from state_claimablePositions[_user] array
            state_claimablePositions[_user][selection] = state_claimablePositions[_user][
                state_claimablePositions[_user].length - 1
            ];
            state_claimablePositions[_user].pop();
            emit DebugPositionClaimed(_user, _positionId, block.timestamp);
            if (enableDebugToFile) {
                line = string.concat(
                    "PositionClaimed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");Id(",
                    Strings.toString(_positionId),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    ")"
                );
                vm.writeLine(path, line);
            }
        } catch Error(string memory revertReason) {
            emit DebugPositionClaimedFailed(
                _user,
                block.timestamp,
                string.concat("PositionClaimedFailed:", revertReason)
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "PositionClaimedFailed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    string.concat(");Reason(", revertReason),
                    ")"
                );
                vm.writeLine(path, line);
            }
        } catch (bytes memory returnData) {
            emit DebugPositionClaimedFailed(
                _user,
                block.timestamp,
                string.concat("PositionClaimedFailed:", vm.toString(returnData))
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "PositionClaimedFailed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    string.concat(");Reason(", vm.toString(returnData)),
                    ")"
                );
                vm.writeLine(path, line);
            }
        }
        vm.stopPrank();
    }

    function wrapper_addLiquidity(address _user) internal {
        /**
            function addLiquidity(
                address market,
                int16 feeRate,
                uint256 amount,
                address recipient
            ) external override returns (LpReceipt memory receipt)
        */
        /**
            Random parameters:
            1. Positive/negative fee rate
            2. Fee Rate - int16
            3. Liquidity Amount
        */
        uint256 randomness;
        bool isPositiveFee;
        randomness = contract_FuzzRandomizer.getRandomNumber() % 2;
        if (randomness == 0) {
            isPositiveFee = true;
        }

        randomness = contract_FuzzRandomizer.getRandomNumber() % 36;

        uint16 selectedFeeRate = validFeeRates[randomness];
        int16 finalFeeRate;
        if (!isPositiveFee) {
            finalFeeRate = -int16(selectedFeeRate);
        } else {
            finalFeeRate = int16(selectedFeeRate);
        }

        vm.startPrank(_user, _user);
        uint256 _userBalance = contract_TestSettlementToken.balanceOf(address(_user));
        uint256 collateralAmount = bound(
            contract_FuzzRandomizer.getRandomNumber(),
            _userBalance / 4,
            _userBalance / 2
        );

        contract_TestSettlementToken.approve(address(contract_ChromaticRouter), collateralAmount);
        try
            contract_ChromaticRouter.addLiquidity(
                address(contract_ChromaticMarket),
                finalFeeRate,
                collateralAmount,
                _user
            )
        returns (LpReceipt memory receipt) {
            state_feeRatesDepos[_user].push(finalFeeRate);
            state_claimableDepos[_user].push(receipt.id);
            emit DebugLiquidityAdded(
                _user,
                receipt.id,
                finalFeeRate,
                collateralAmount,
                block.timestamp
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "LiquidityAdded;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");Id(",
                    Strings.toString(receipt.id),
                    ");FeeRate(",
                    vm.toString(finalFeeRate),
                    ");CollateralAmount(",
                    Strings.toString(collateralAmount),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    ")"
                );
                vm.writeLine(path, line);
            }
        } catch Error(string memory revertReason) {
            emit DebugLiquidityAddedFailed(
                _user,
                block.timestamp,
                string.concat("LiquidityAddedFailed:", revertReason)
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "LiquidityAddedFailed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    string.concat(");Reason(", revertReason),
                    ")"
                );
                vm.writeLine(path, line);
            }
        } catch (bytes memory returnData) {
            emit DebugLiquidityAddedFailed(
                _user,
                block.timestamp,
                string.concat("LiquidityAddedFailed:", vm.toString(returnData))
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "LiquidityAddedFailed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    string.concat(");Reason(", vm.toString(returnData)),
                    ")"
                );
                vm.writeLine(path, line);
            }
        }
        vm.stopPrank();
    }

    function wrapper_claimLiquidity(address _user) internal {
        vm.startPrank(_user, _user);
        for (uint256 i; i < state_claimableDepos[_user].length; ++i) {
            uint256 id = state_claimableDepos[_user][i];
            contract_ChromaticRouter.claimLiquidity(address(contract_ChromaticMarket), id);
            emit DebugLiquidityClaimed(_user, id, block.timestamp);
            if (enableDebugToFile) {
                line = string.concat(
                    "LiquidityClaimed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");Id(",
                    Strings.toString(id),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    ")"
                );
                vm.writeLine(path, line);
            }
        }
        delete state_claimableDepos[_user];
        vm.stopPrank();
    }

    function wrapper_removeLiquidity(address _user) internal {
        /**
            function removeLiquidity(
                address market,
                int16 feeRate,
                uint256 clbTokenAmount,
                address recipient
            ) external override returns (LpReceipt memory receipt) 
        */
        /**
            Random parameters:
            1. Select feeRate (if any)
            2. Liquidity Amount
        */
        uint256 removableFeesLen = state_feeRatesDepos[_user].length;
        if (removableFeesLen == 0) {
            emit DebugLiquidityRemovedFailed(
                _user,
                block.timestamp,
                string.concat("LiquidityRemovedFailed:", "NO_REMOVABLE_POS")
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "LiquidityRemovedFailed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    string.concat(");Reason(NO_REMOVABLE_POS)")
                );
                vm.writeLine(path, line);
            }
            return;
        }
        // 1. Select feeRate
        uint256 selection = contract_FuzzRandomizer.getRandomNumber() % removableFeesLen;
        int16 feeRate = state_feeRatesDepos[_user][selection];
        bool isPositiveFee;
        if (feeRate > 0) {
            isPositiveFee = true;
        }
        // 2. Liquidity Amount
        uint256 CLBTokenId = encodeId(feeRate);
        uint256 CLBBalance = contract_CLBToken.balanceOf(_user, CLBTokenId);
        if (CLBBalance == 0) {
            wrapper_claimLiquidity(_user);
        }
        CLBBalance = contract_CLBToken.balanceOf(_user, CLBTokenId);
        if (CLBBalance == 0) {
            emit DebugLiquidityRemovedFailed(
                _user,
                block.timestamp,
                string.concat("LiquidityRemovedFailed:", "NO_BALANCE")
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "LiquidityRemovedFailed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    string.concat(");Reason(NO_BALANCE)")
                );
                vm.writeLine(path, line);
            }
            return;
        }
        uint256 randomness = contract_FuzzRandomizer.getRandomNumber() % 2;
        uint256 removeAmount;
        // 50% chance of removing the whole amount
        if (randomness == 0) {
            removeAmount = CLBBalance;
            emit DebugUint("removeAmount", removeAmount);
        } else {
            // Remove between the 25% of the total amount and the whole amount - 1
            emit DebugUint("CLBBalance", CLBBalance);
            removeAmount = bound(
                contract_FuzzRandomizer.getRandomNumber(),
                CLBBalance / 4,
                CLBBalance - 1
            );
        }

        vm.startPrank(_user, _user);
        contract_CLBToken.setApprovalForAll(address(contract_ChromaticRouter), true);
        try
            contract_ChromaticRouter.removeLiquidity(
                address(contract_ChromaticMarket),
                feeRate,
                removeAmount,
                _user
            )
        returns (LpReceipt memory receipt) {
            state_allLpReceiptsOracleVersionsFromRemoveLiq.push(receipt.oracleVersion);
            state_claimableWithdrawals[_user].push(receipt.id);
            // Remove position from state_feeRatesDepos[_user] array
            if (randomness == 0) {
                state_feeRatesDepos[_user][selection] = state_feeRatesDepos[_user][
                    state_feeRatesDepos[_user].length - 1
                ];
                state_feeRatesDepos[_user].pop();
            }
            emit DebugLiquidityRemoved(_user, receipt.id, feeRate, removeAmount, block.timestamp);
            if (enableDebugToFile) {
                line = string.concat(
                    "LiquidityRemoved;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");Id(",
                    Strings.toString(receipt.id),
                    ");FeeRate(",
                    vm.toString(feeRate),
                    ");RemovedAmount(",
                    Strings.toString(removeAmount),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    ")"
                );
                vm.writeLine(path, line);
            }
        } catch Error(string memory revertReason) {
            emit DebugLiquidityRemovedFailed(
                _user,
                block.timestamp,
                string.concat("LiquidityRemovedFailed:", revertReason)
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "LiquidityRemovedFailed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    string.concat(");Reason(", revertReason),
                    ")"
                );
                vm.writeLine(path, line);
            }
        } catch (bytes memory returnData) {
            emit DebugLiquidityRemovedFailed(
                _user,
                block.timestamp,
                string.concat("LiquidityRemovedFailed:", vm.toString(returnData))
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "LiquidityRemovedFailed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    string.concat(");Reason(", vm.toString(returnData)),
                    ")"
                );
                vm.writeLine(path, line);
            }
        }
        vm.stopPrank();
    }

    function wrapper_withdrawLiquidity(address _user) internal {
        /**
            function withdrawLiquidity(address market, uint256 receiptId) external override
        */
        /**
            Random parameters:
            1. Select receiptId
        */
        uint256 withdrawableLiqLen = state_claimableWithdrawals[_user].length;
        if (withdrawableLiqLen == 0) {
            emit DebugLiquidityWithdrawnFailed(
                _user,
                block.timestamp,
                string.concat("LiquidityWithdrawnFailed:", "NO_WITHDRAWABLE_POS")
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "LiquidityWithdrawnFailed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    string.concat(");Reason(NO_WITHDRAWABLE_POS)")
                );
                vm.writeLine(path, line);
            }
            return;
        }
        // 1. Select receiptId
        uint256 selection = contract_FuzzRandomizer.getRandomNumber() % withdrawableLiqLen;
        uint256 receiptId = state_claimableWithdrawals[_user][selection];
        uint256 balBefore = contract_TestSettlementToken.balanceOf(_user);
        // Execute the withdrawal
        try
            contract_ChromaticRouter.withdrawLiquidity(address(contract_ChromaticMarket), receiptId)
        {
            uint256 received = contract_TestSettlementToken.balanceOf(_user) - balBefore;
            state_claimableWithdrawals[_user][selection] = state_claimableWithdrawals[_user][
                state_claimableWithdrawals[_user].length - 1
            ];
            state_claimableWithdrawals[_user].pop();
            emit DebugLiquidityWithdrawn(_user, receiptId, received, block.timestamp);
            if (enableDebugToFile) {
                line = string.concat(
                    "LiquidityWithdrawn;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");Id(",
                    Strings.toString(receiptId),
                    ");ReceivedAmount(",
                    Strings.toString(received),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    ")"
                );
                vm.writeLine(path, line);
            }
        } catch Error(string memory revertReason) {
            emit DebugLiquidityWithdrawnFailed(
                _user,
                block.timestamp,
                string.concat("LiquidityWithdrawnFailed:", revertReason)
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "LiquidityWithdrawnFailed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    string.concat(");Reason(", revertReason),
                    ")"
                );
                vm.writeLine(path, line);
            }
        } catch (bytes memory returnData) {
            emit DebugLiquidityWithdrawnFailed(
                _user,
                block.timestamp,
                string.concat("LiquidityWithdrawnFailed:", vm.toString(returnData))
            );
            if (enableDebugToFile) {
                line = string.concat(
                    "LiquidityWithdrawnFailed;User(",
                    Strings.toHexString(uint160(_user), 20),
                    ");TimeStamp(",
                    Strings.toString(block.timestamp),
                    string.concat(");Reason(", vm.toString(returnData)),
                    ")"
                );
                vm.writeLine(path, line);
            }
        }
        vm.stopPrank();
    }
}
