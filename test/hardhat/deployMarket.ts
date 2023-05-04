import { ethers, deployments } from "hardhat"
import { deploy as gelatoDeploy } from "./gelato/deploy"
import { deploy as marketFactoryDeploy } from "./market_factory/deploy"
import { deploy as oracleProviderDeploy } from "./oracle_provider/deploy"
import { deployContract, hardhatErrorPrettyPrint } from "./utils"
import { Token, AccountFactory, USUMRouter } from "../../typechain-types"

export async function deploy() {
  return hardhatErrorPrettyPrint(async () => {
    const { gelato, taskTreasury, opsProxyFactory, automate } = await gelatoDeploy()
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
      await marketFactory.registerSettlementToken(settlementToken.address)
    ).wait()

    await (
      await marketFactory.createMarket(
        oracleProvider.address,
        settlementToken.address
      )
    ).wait()

    const marketAddress = await marketFactory.getMarket(
      oracleProvider.address,
      settlementToken.address
    )
    const market = await ethers.getContractAt("USUMMarket", marketAddress)

    const usumRouter = await deployContract<USUMRouter>("USUMRouter")
    const accountFactory = await deployContract<AccountFactory>(
      "AccountFactory",
      { args: [usumRouter.address] }
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
      gelato : {
        gelato, taskTreasury, opsProxyFactory, automate
      }
    }
  })
}
