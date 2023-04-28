import { ethers, deployments } from "hardhat"
import { deploy as gelatoDeploy } from "./gelato/deploy"
import { deploy as marketFactoryDeploy } from "./market_factory/deploy"
import { deploy as oracleProviderDeploy } from "./oracle_provider/deploy"
import { deployContract } from "./utils"
import { Token, AccountFactory, USUMRouter } from "../../typechain-types"

export async function deploy() {
  const { gelato, taskTreasury, opsProxyFactory, ops } = await gelatoDeploy()
  const { oracleProviderRegistry, marketFactory, keeperFeePayer, liquidator } =
    await marketFactoryDeploy(ops.address)
  const oracleProvider = await oracleProviderDeploy()
  const settlementToken = await deployContract<Token>("Token", {
    args: ["Token", "ST"],
  })

  await (
    await oracleProviderRegistry.register(
      ethers.Wallet.createRandom().address,
      ethers.Wallet.createRandom().address,
      oracleProvider.address
    )
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
    await usumRouter.initalize(accountFactory.address, marketFactory.address)
  ).wait()

  return {
    oracleProviderRegistry,
    marketFactory,
    keeperFeePayer,
    liquidator,
    oracleProvider,
    market,
    usumRouter,
    accountFactory,
    settlementToken
  }
}
