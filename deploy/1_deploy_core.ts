import { GELATO_ADDRESSES } from '@gelatonetwork/automate-sdk'
import { SWAP_ROUTER_02_ADDRESSES, WETH9 } from '@uniswap/smart-order-router'
import chalk from 'chalk'
import { constants } from 'ethers'
import type { DeployFunction } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'

const ARB_GOERLI_SWAP_ROUTER_ADDRESS = '0xF1596041557707B1bC0b3ffB34346c1D9Ce94E86'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { config, deployments, getNamedAccounts, ethers, network } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const echainId =
    network.name === 'anvil' ? config.networks.arbitrum_goerli.chainId! : network.config.chainId!

  console.log(chalk.yellow(`✨ Deploying... to ${network.name}`))

  const swapRouterAddress =
    echainId === config.networks.arbitrum_goerli.chainId!
      ? ARB_GOERLI_SWAP_ROUTER_ADDRESS
      : SWAP_ROUTER_02_ADDRESSES(echainId)

  const { address: clbTokenDeployer } = await deploy('CLBTokenDeployerLib', {
    from: deployer
  })
  console.log(chalk.yellow(`✨ CLBTokenDeployerLib: ${clbTokenDeployer}`))

  const { address: marketDeployer } = await deploy('MarketDeployerLib', {
    from: deployer,
    libraries: {
      CLBTokenDeployerLib: clbTokenDeployer
    }
  })
  console.log(chalk.yellow(`✨ MarketDeployerLib: ${marketDeployer}`))

  const { address: factory, libraries } = await deploy('ChromaticMarketFactory', {
    from: deployer,
    libraries: {
      MarketDeployerLib: marketDeployer
    }
  })
  console.log(chalk.yellow(`✨ ChromaticMarketFactory: ${factory}`))

  const MarketFactory = await ethers.getContractFactory('ChromaticMarketFactory', {
    libraries
  })
  const marketFactory = MarketFactory.attach(factory)

  // deploy & set KeeperFeePayer

  const { address: keeperFeePayer } = await deploy('KeeperFeePayer', {
    from: deployer,
    args: [factory, swapRouterAddress, WETH9[echainId].address]
  })
  console.log(chalk.yellow(`✨ KeeperFeePayer: ${keeperFeePayer}`))

  await marketFactory.setKeeperFeePayer(keeperFeePayer, {
    from: deployer
  })
  console.log(chalk.yellow('✨ Set KeeperFeePayer'))

  // deploy & set ChromaticVault

  const { address: vault } = await deploy('ChromaticVault', {
    from: deployer,
    args: [factory, GELATO_ADDRESSES[echainId].automate, constants.AddressZero]
  })
  console.log(chalk.yellow(`✨ ChromaticVault: ${vault}`))

  await marketFactory.setVault(vault, {
    from: deployer
  })
  console.log(chalk.yellow('✨ Set Vault'))

  // deploy & set ChromaticLiquidator

  const { address: liquidator } = await deploy(
    network.name === 'anvil' ? 'ChromaticLiquidatorMock' : 'ChromaticLiquidator',
    {
      from: deployer,
      args: [factory, GELATO_ADDRESSES[echainId].automate, constants.AddressZero]
    }
  )
  console.log(chalk.yellow(`✨ ChromaticLiquidator: ${liquidator}`))

  await marketFactory.setLiquidator(liquidator, {
    from: deployer
  })
  console.log(chalk.yellow('✨ Set Liquidator'))
}

export default func

func.id = 'deploy_core' // id required to prevent reexecution
func.tags = ['core']
