import { ChromaticMarketFactory__factory } from '@chromatic/typechain-types'
import { GELATO_ADDRESSES } from '@gelatonetwork/automate-sdk'
import { WETH9 } from '@uniswap/smart-order-router'
import chalk from 'chalk'
import type { DeployFunction } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
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

export default func

func.id = 'deploy_core_for_chain' // id required to prevent reexecution
func.tags = ['arbitrum']
