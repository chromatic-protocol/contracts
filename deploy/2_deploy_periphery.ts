import chalk from "chalk"
import { DeployFunction } from "hardhat-deploy/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const { address: routerAddress } = await deploy("USUMRouter", {
    from: deployer,
  })
  console.log(chalk.yellow(`✨ USUMRouter: ${routerAddress}`))


  const { address: marketFactoryAddress } = await deployments.get(
    "USUMMarketFactory"
  )


  const { address: accountFactoryAddress } = await deploy("AccountFactory", {
    from: deployer,
    args: [routerAddress, marketFactoryAddress],
  })
  console.log(chalk.yellow(`✨ AccountFactory: ${accountFactoryAddress}`))

  const Router = await ethers.getContractFactory("USUMRouter")
  const router = Router.attach(routerAddress)
  await router.initialize(accountFactoryAddress, marketFactoryAddress, {
    from: deployer,
  })
  console.log(chalk.yellow("✨ Initialize USUMRouter"))
}

export default func

func.id = "deploy_periphery" // id required to prevent reexecution
func.tags = ["periphery"]
