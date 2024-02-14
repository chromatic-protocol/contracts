import {
  ChromaticMarketFactory__factory,
  IMate2AutomationRegistry1_1__factory
} from '@chromatic/typechain-types'
import { GELATO_ADDRESSES } from '@gelatonetwork/automate-sdk'
import { WETH9 } from '@uniswap/smart-order-router'
import chalk from 'chalk'
import type { DeployFunction } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'

export const MATE2_AUTOMATION_ADDRESS: { [key: number]: string } = {
  421614: '0x14cC9A5B88425d357AEca1B13B8cd6F81388Fe86',
  31337: '0x14cC9A5B88425d357AEca1B13B8cd6F81388Fe86' // same to forked from arbitrum_sepolia
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { config, deployments, getNamedAccounts, ethers, network } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const echainId: keyof typeof WETH9 =
    network.name === 'anvil' ? config.networks.arbitrum_sepolia.chainId! : network.config.chainId!

  const automationAddress = MATE2_AUTOMATION_ADDRESS[echainId]

  console.log(chalk.yellow(`✨ Deploying... to ${network.name}`))

  const deployOpts = { from: deployer }
  const factory = await deployments.get('ChromaticMarketFactory')
  console.log('factory.address', factory.address)
  const marketFactory = ChromaticMarketFactory__factory.connect(
    factory.address,
    await ethers.getSigner(deployer)
  )

  // deploy & set ChromaticVault
  const { address: distributor } = await deploy('Mate2VaultEarningDistributor', {
    ...deployOpts,
    args: [factory.address, automationAddress]
  })
  console.log(chalk.yellow(`✨ Mate2VaultEarningDistributor: ${distributor}`))

  const mate2automate = IMate2AutomationRegistry1_1__factory.connect(
    automationAddress,
    await ethers.getSigner(deployer)
  )
  await (await mate2automate.addWhitelistedRegistrar(distributor)).wait()

  const { address: vault } = await deploy('ChromaticVault', {
    ...deployOpts,
    args: [factory.address, distributor]
  })
  console.log(chalk.yellow(`✨ ChromaticVault: ${vault}`))

  await marketFactory.setVault(vault, deployOpts)
  console.log(chalk.yellow('✨ Set Vault'))

  // deploy & set Liquidator

  const { address: liquidator } = await deploy('Mate2Liquidator', {
    ...deployOpts,
    args: [factory.address, automationAddress]
  })
  console.log(chalk.yellow(`✨ Mate2Liquidator: ${liquidator}`))

  await (await mate2automate.addWhitelistedRegistrar(liquidator)).wait()
  await marketFactory.updateLiquidator(liquidator, deployOpts)
  console.log(chalk.yellow('✨ Set Liquidator'))

  /*
  const { address: marketSettlement } = await deploy('Mate2MarketSettlement', {
    ...deployOpts,
    args: [factory.address, automationAddress]
  })
  console.log(chalk.yellow(`✨ Mate2MarketSettlement: ${marketSettlement}`))

  await (await mate2automate.addWhitelistedRegistrar(marketSettlement)).wait()
  await marketFactory.updateMarketSettlement(marketSettlement, deployOpts)
  console.log(chalk.yellow('✨ Set MarketSettlement'))
  */
}

export default func

func.id = 'deploy_core_for_chain' // id required to prevent reexecution
func.tags = ['arbitrum']

const _func_for_gelato: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { config, deployments, getNamedAccounts, ethers, network } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const echainId: keyof typeof WETH9 =
    network.name === 'anvil' ? config.networks.arbitrum_sepolia.chainId! : network.config.chainId!

  console.log(chalk.yellow(`✨ Deploying... to ${network.name}`))

  const deployOpts = { from: deployer }
  const factory = await deployments.get('ChromaticMarketFactory')
  const marketFactory = ChromaticMarketFactory__factory.connect(
    factory.address,
    await ethers.getSigner(deployer)
  )

  // deploy & set ChromaticVault
  console.log('gelato automate address', GELATO_ADDRESSES[echainId].automate)
  const { address: distributor } = await deploy('GelatoVaultEarningDistributor', {
    ...deployOpts,
    args: [factory.address, GELATO_ADDRESSES[echainId].automate]
  })
  console.log(chalk.yellow(`✨ GelatoVaultEarningDistributor: ${distributor}`))

  const { address: vault } = await deploy('ChromaticVault', {
    ...deployOpts,
    args: [factory.address, distributor]
  })
  console.log(chalk.yellow(`✨ ChromaticVault: ${vault}`))

  await marketFactory.setVault(vault, deployOpts)
  console.log(chalk.yellow('✨ Set Vault'))

  // deploy & set Liquidator

  const { address: liquidator } = await deploy(
    network.name === 'anvil' ? 'GelatoLiquidatorMock' : 'GelatoLiquidator',
    {
      ...deployOpts,
      args: [factory.address, GELATO_ADDRESSES[echainId].automate]
    }
  )
  console.log(chalk.yellow(`✨ GelatoLiquidator: ${liquidator}`))

  await marketFactory.updateLiquidator(liquidator, deployOpts)
  console.log(chalk.yellow('✨ Set Liquidator'))
}
