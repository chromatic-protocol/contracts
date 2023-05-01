import chalk from "chalk"
import { DeployFunction } from "hardhat-deploy/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const ARB_GOERLI_USDC_ADDRESS = "0x8FB1E3fC51F3b789dED7557E680551d93Ea9d892"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const { address: oracleProviderAddress } = await deploy(
    "OracleProviderMock",
    {
      from: deployer,
    }
  )
  console.log(chalk.yellow(`✨ OracleProviderMock: ${oracleProviderAddress}`))

  const { address: marketFactoryAddress, libraries: marketFactoryLibaries } =
    await deployments.get("USUMMarketFactory")

  const MarketFactory = await ethers.getContractFactory("USUMMarketFactory", {
    libraries: marketFactoryLibaries,
  })
  const marketFactory = MarketFactory.attach(marketFactoryAddress)

  await marketFactory.registerOracleProvider(oracleProviderAddress, {
    from: deployer,
  })
  console.log(chalk.yellow("✨ Register OracleProvider"))

  await marketFactory.registerSettlementToken(ARB_GOERLI_USDC_ADDRESS, {
    from: deployer,
  })
  console.log(chalk.yellow("✨ Register SettlementToken"))

  await marketFactory.createMarket(
    oracleProviderAddress,
    ARB_GOERLI_USDC_ADDRESS,
    { from: deployer }
  )
  console.log(chalk.yellow("✨ Create Market"))
}

export default func

func.id = "deploy_mockup" // id required to prevent reexecution
func.tags = ["mockup"]
