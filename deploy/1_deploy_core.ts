import { ChromaticMarketFactory } from '@chromatic/typechain-types'
import { SWAP_ROUTER_02_ADDRESSES, WETH9 } from '@uniswap/smart-order-router'
import chalk from 'chalk'
import type { DeployFunction } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'

const SWAP_ROUTER_ADDRESS: { [key: number]: string } = {
  421613: '0xF1596041557707B1bC0b3ffB34346c1D9Ce94E86', // arbitrum_goerli UNISWAP
  5000: '0x319B69888b0d11cEC22caA5034e25FfFBDc88421', // mantle AGNI
  5001: '0xe2DB835566F8677d6889ffFC4F3304e8Df5Fc1df' // mantle_testnet AGNI
}

const WMNT: { [key: number]: string } = {
  5000: '0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8', // mantle
  5001: '0xea12be2389c2254baad383c6ed1fa1e15202b52a' // mantle_testnet
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { config, deployments, getNamedAccounts, ethers, network } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const echainId: keyof typeof WETH9 =
    network.name === 'anvil'
      ? config.networks.arbitrum_goerli.chainId!
      : network.name === 'anvil_mantle'
      ? config.networks.mantle_testnet.chainId!
      : network.config.chainId!

  console.log(chalk.yellow(`✨ Deploying... to ${network.name}`))

  const swapRouterAddress = SWAP_ROUTER_ADDRESS[echainId] ?? SWAP_ROUTER_02_ADDRESSES(echainId)

  const deployOpts = { from: deployer }

  const { address: clbTokenDeployer } = await deploy('CLBTokenDeployerLib', deployOpts)
  console.log(chalk.yellow(`✨ CLBTokenDeployerLib: ${clbTokenDeployer}`))

  const { address: marketDeployer } = await deploy('MarketDeployerLib', {
    ...deployOpts,
    libraries: {
      CLBTokenDeployerLib: clbTokenDeployer
    }
  })
  console.log(chalk.yellow(`✨ MarketDeployerLib: ${marketDeployer}`))

  const { address: marketDiamondCutFacet } = await deploy('MarketDiamondCutFacet', deployOpts)
  console.log(chalk.yellow(`✨ MarketDiamondCutFacet: ${marketDiamondCutFacet}`))

  const { address: marketLoupeFacet } = await deploy('DiamondLoupeFacet', deployOpts)
  console.log(chalk.yellow(`✨ DiamondLoupeFacet: ${marketLoupeFacet}`))

  const { address: marketStateFacet } = await deploy('MarketStateFacet', deployOpts)
  console.log(chalk.yellow(`✨ MarketStateFacet: ${marketStateFacet}`))

  const { address: marketLiquidityFacet } = await deploy('MarketLiquidityFacet', deployOpts)
  console.log(chalk.yellow(`✨ MarketLiquidityFacet: ${marketLiquidityFacet}`))

  const { address: marketLensFacet } = await deploy('MarketLensFacet', deployOpts)
  console.log(chalk.yellow(`✨ MarketLensFacet: ${marketLensFacet}`))

  const { address: marketTradeFacet } = await deploy('MarketTradeFacet', deployOpts)
  console.log(chalk.yellow(`✨ MarketTradeFacet: ${marketTradeFacet}`))

  const { address: marketLiquidateFacet } = await deploy('MarketLiquidateFacet', deployOpts)
  console.log(chalk.yellow(`✨ MarketLiquidateFacet: ${marketLiquidateFacet}`))

  const { address: marketSettleFacet } = await deploy('MarketSettleFacet', deployOpts)
  console.log(chalk.yellow(`✨ MarketSettleFacet: ${marketSettleFacet}`))

  const { address: factory, libraries: factoryLibraries } = await deploy('ChromaticMarketFactory', {
    ...deployOpts,
    args: [
      marketDiamondCutFacet,
      marketLoupeFacet,
      marketStateFacet,
      marketLiquidityFacet,
      marketLensFacet,
      marketTradeFacet,
      marketLiquidateFacet,
      marketSettleFacet
    ],
    libraries: {
      MarketDeployerLib: marketDeployer
    }
  })
  console.log(chalk.yellow(`✨ ChromaticMarketFactory: ${factory}`))

  const MarketFactory = await ethers.getContractFactory('ChromaticMarketFactory', {
    libraries: factoryLibraries
  })
  const marketFactory = MarketFactory.attach(factory) as ChromaticMarketFactory

  // deploy & set KeeperFeePayer

  const wrappedTokenAddress = WMNT[echainId] ?? WETH9[echainId].address

  const { address: keeperFeePayer } = await deploy('KeeperFeePayer', {
    ...deployOpts,
    args: [factory, swapRouterAddress, wrappedTokenAddress]
  })
  console.log(chalk.yellow(`✨ KeeperFeePayer: ${keeperFeePayer}`))

  await marketFactory.setKeeperFeePayer(keeperFeePayer, deployOpts)
  console.log(chalk.yellow('✨ Set KeeperFeePayer'))
}

export default func

func.id = 'deploy_core' // id required to prevent reexecution
func.tags = ['core']
