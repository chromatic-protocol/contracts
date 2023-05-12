import { ethers, deployments } from "hardhat"
import { deploy as gelatoDeploy } from "./gelato/deploy"
import { deploy as marketFactoryDeploy } from "./market_factory/deploy"
import { deploy as oracleProviderDeploy } from "./oracle_provider/deploy"
import { deployContract, hardhatErrorPrettyPrint } from "./utils"
import { Token, AccountFactory, USUMRouter } from "../../typechain-types"
import { BigNumber } from "ethers"
import { parseUnits } from "ethers/lib/utils"
import { USDC_ARBITRUM_GOERLI } from "@uniswap/smart-order-router"

export async function deploy() {
  return hardhatErrorPrettyPrint(async () => {
    const { gelato, taskTreasury, opsProxyFactory, automate } =
      await gelatoDeploy()
    const { marketFactory, keeperFeePayer, liquidator } =
      await marketFactoryDeploy(automate.address, opsProxyFactory.address)
    const oracleProvider = await oracleProviderDeploy()
    const settlementToken = await deployContract<Token>("Token", {
      args: ["Token", "ST"],
    })

    await (
      await marketFactory.registerOracleProvider(oracleProvider.address)
    ).wait()

    await (
      await marketFactory.registerSettlementToken(
        settlementToken.address,
        parseUnits("10", USDC_ARBITRUM_GOERLI.decimals), // minimumTakerMargin
        BigNumber.from("1000"), // interestRate, 10%
        BigNumber.from("500"), // flashLoanFeeRate, 5%
        parseUnits("1000", USDC_ARBITRUM_GOERLI.decimals), // earningDistributionThreshold, $1000
        BigNumber.from("3000") // uniswapFeeRate, 0.3%)
      )
    ).wait()

    const marketCreateResult = await (
      await marketFactory.createMarket(
        oracleProvider.address,
        settlementToken.address
      )
    ).wait()
    const marketCreatedEvents = await marketFactory.queryFilter(
      marketFactory.filters.MarketCreated()
    )
    const marketAddress = marketCreatedEvents[0].args.market
    console.log("market create result ", marketAddress)

    const market = await ethers.getContractAt("USUMMarket", marketAddress)

    const usumRouter = await deployContract<USUMRouter>("USUMRouter")
    const accountFactory = await deployContract<AccountFactory>(
      "AccountFactory",
      { args: [usumRouter.address, marketFactory.address] }
    )

    await (
      await usumRouter.initialize(accountFactory.address, marketFactory.address)
    ).wait()

    return {
      marketFactory,
      keeperFeePayer,
      liquidator,
      oracleProvider,
      market,
      usumRouter,
      accountFactory,
      settlementToken,
      gelato: {
        gelato,
        taskTreasury,
        opsProxyFactory,
        automate,
      },
    }
  })
}
