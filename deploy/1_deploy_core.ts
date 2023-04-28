import { GELATO_ADDRESSES } from "@gelatonetwork/automate-sdk"
import chalk from "chalk"
import type { DeployFunction } from "hardhat-deploy/types"
import type { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network, ethers } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  console.log(chalk.yellow(`✨ Deploying... to ${network.name}`))

  let automateAddress =
    GELATO_ADDRESSES[
      network.name === "anvil" ? 421613 : network.config.chainId!
    ].automate
  // FIXME
  let keeperFeePayer = ethers.constants.AddressZero

  let { address: liquidator } = await deploy("USUMLiquidator", {
    from: deployer,
    args: [automateAddress],
  })

  // // FIXME: need ops mock or real one
  // await deploy("USUMMarketFactory", {
  //   from: deployer,
  //   args: [oracleRegistry, liquidator, keeperFeePayer],
  // });
  console.log(chalk.yellow(`✨ USUMLiquidator: ${liquidator}`))
}

export default func

func.id = "deploy_core" // id required to prevent reexecution
func.tags = ["core"]
