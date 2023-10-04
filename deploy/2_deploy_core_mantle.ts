import {
  ChromaticMarketFactory__factory,
  IMate2AutomationRegistry__factory
} from '@chromatic/typechain-types'
import chalk from 'chalk'
import type { DeployFunction } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'

export const MATE2_AUTOMATION_ADDRESS: { [key: number]: string } = {
  31337: '0xe1Fd27F4390DcBE165f4D60DBF821e4B9Bb02dEd',
  5001: '0xF4564c2310680c4F19f2625842E3875A98c110A3'
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { config, deployments, getNamedAccounts, ethers, network } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()
  const automationAddress = MATE2_AUTOMATION_ADDRESS[network.config.chainId!]

  console.log(chalk.yellow(`✨ Deploying... to ${network.name}`))

  const deployOpts = { from: deployer }
  const factory = await deployments.get('ChromaticMarketFactory')
  const marketFactory = ChromaticMarketFactory__factory.connect(
    factory.address,
    await ethers.getSigner(deployer)
  )

  const { address: distributor } = await deploy('Mate2VaultEarningDistributor', {
    ...deployOpts,
    args: [factory.address, automationAddress]
  })
  console.log(chalk.yellow(`✨ Mate2VaultEarningDistributor: ${distributor}`))

  const mate2automate = IMate2AutomationRegistry__factory.connect(
    automationAddress,
    await ethers.getSigner(deployer)
  )
  await (await mate2automate.addWhitelistedRegistrar(distributor)).wait()
  const { address: vault } = await deploy('ChromaticVault', {
    ...deployOpts,
    args: [factory.address, distributor]
  })
  await marketFactory.setVault(vault, deployOpts)
  console.log(chalk.yellow(`✨ ChromaticVault: ${vault}`))

  const { address: liquidator } = await deploy('Mate2Liquidator', {
    ...deployOpts,
    args: [factory.address, automationAddress]
  })
  console.log(chalk.yellow(`✨ Mate2Liquidator: ${liquidator}`))

  await (await mate2automate.addWhitelistedRegistrar(liquidator)).wait()
  await marketFactory.setLiquidator(liquidator, deployOpts)
  console.log(chalk.yellow('✨ Set Liquidator'))

  const { address: marketSettlement } = await deploy('Mate2MarketSettlement', {
    ...deployOpts,
    args: [factory.address, automationAddress]
  })
  console.log(chalk.yellow(`✨ Mate2MarketSettlement: ${marketSettlement}`))

  await (await mate2automate.addWhitelistedRegistrar(marketSettlement)).wait()
  await marketFactory.setMarketSettlement(marketSettlement, deployOpts)
  console.log(chalk.yellow('✨ Set MarketSettlement'))
}

export default func

func.id = 'deploy_core_for_chain' // id required to prevent reexecution
func.tags = ['mantle']
