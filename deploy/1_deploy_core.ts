import { GELATO_ADDRESSES } from "@gelatonetwork/automate-sdk"
import { SWAP_ROUTER_02_ADDRESSES, WETH9 } from "@uniswap/smart-order-router"
import chalk from "chalk"
import { constants } from "ethers"
import type { DeployFunction } from "hardhat-deploy/types"
import type { HardhatRuntimeEnvironment } from "hardhat/types"

const ARB_GOERLI_SWAP_ROUTER_ADDRESS =
  "0xF1596041557707B1bC0b3ffB34346c1D9Ce94E86"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { config, deployments, getNamedAccounts, ethers, network } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const echainId =
    network.name === "anvil"
      ? config.networks.arbitrum_one_goerli.chainId!
      : network.config.chainId!

  console.log(chalk.yellow(`✨ Deploying... to ${network.name}`))

  const swapRouterAddress =
    echainId === config.networks.arbitrum_one_goerli.chainId!
      ? ARB_GOERLI_SWAP_ROUTER_ADDRESS
      : SWAP_ROUTER_02_ADDRESSES(echainId)

  const { address: lpSlotSet } = await deploy("LpSlotSetLib", {
    from: deployer,
  })
  console.log(chalk.yellow(`✨ LpSlotSetLib: ${lpSlotSet}`))

  const { address: marketDeployer } = await deploy("MarketDeployerLib", {
    from: deployer,
    libraries: {
      LpSlotSetLib: lpSlotSet,
    },
  })
  console.log(chalk.yellow(`✨ MarketDeployerLib: ${marketDeployer}`))

  const { address: oracleProviderRegistry } = await deploy(
    "OracleProviderRegistryLib",
    {
      from: deployer,
    }
  )
  console.log(
    chalk.yellow(`✨ OracleProviderRegistryLib: ${oracleProviderRegistry}`)
  )

  const { address: settlementTokenRegistry } = await deploy(
    "SettlementTokenRegistryLib",
    {
      from: deployer,
    }
  )
  console.log(
    chalk.yellow(`✨ SettlementTokenRegistryLib: ${settlementTokenRegistry}`)
  )

  const { address: factory, libraries } = await deploy("USUMMarketFactory", {
    from: deployer,
    libraries: {
      MarketDeployerLib: marketDeployer,
      OracleProviderRegistryLib: oracleProviderRegistry,
      SettlementTokenRegistryLib: settlementTokenRegistry,
    },
  })
  console.log(chalk.yellow(`✨ USUMMarketFactory: ${factory}`))

  const MarketFactory = await ethers.getContractFactory("USUMMarketFactory", {
    libraries,
  })
  const marketFactory = MarketFactory.attach(factory)

  // deploy & set KeeperFeePayer

  const { address: keeperFeePayer } = await deploy("KeeperFeePayer", {
    from: deployer,
    args: [factory, swapRouterAddress, WETH9[echainId].address],
  })
  console.log(chalk.yellow(`✨ KeeperFeePayer: ${keeperFeePayer}`))

  await marketFactory.setKeeperFeePayer(keeperFeePayer, {
    from: deployer,
  })
  console.log(chalk.yellow("✨ Set KeeperFeePayer"))

  // deploy & set USUMVault

  const { address: vault } = await deploy("USUMVault", {
    from: deployer,
    args: [factory],
  })
  console.log(chalk.yellow(`✨ USUMVault: ${vault}`))

  await marketFactory.setVault(vault, {
    from: deployer,
  })
  console.log(chalk.yellow("✨ Set Vault"))

  // deploy & set USUMLiquidator

  const { address: liquidator } = await deploy(
    network.name === "anvil" ? "USUMLiquidatorMock" : "USUMLiquidator",
    {
      from: deployer,
      args: [
        factory,
        GELATO_ADDRESSES[echainId].automate,
        constants.AddressZero,
      ],
    }
  )
  console.log(chalk.yellow(`✨ USUMLiquidator: ${liquidator}`))

  await marketFactory.setLiquidator(liquidator, {
    from: deployer,
  })
  console.log(chalk.yellow("✨ Set Liquidator"))
}

export default func

func.id = "deploy_core" // id required to prevent reexecution
func.tags = ["core"]
