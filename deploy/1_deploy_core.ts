import { verify } from '@chromatic/deploy/verify'
import { ChromaticMarketFactory } from '@chromatic/typechain-types'
import { GELATO_ADDRESSES } from '@gelatonetwork/automate-sdk'
import { SWAP_ROUTER_02_ADDRESSES, WETH9 } from '@uniswap/smart-order-router'
import chalk from 'chalk'
import { ZeroAddress } from 'ethers'
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

//FIXME MATE2 automate contract address
const MATE2_AUTOMATION_ADDRESS = '0x'
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { config, deployments, getNamedAccounts, ethers, network } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const echainId: keyof typeof WETH9 =
    network.name === 'anvil' ? config.networks.arbitrum_goerli.chainId! : network.config.chainId!

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
  await verify(hre, { address: marketDiamondCutFacet })
  console.log(chalk.yellow(`✨ MarketDiamondCutFacet: ${marketDiamondCutFacet}`))

  const { address: marketLoupeFacet } = await deploy('DiamondLoupeFacet', deployOpts)
  await verify(hre, { address: marketLoupeFacet })
  console.log(chalk.yellow(`✨ DiamondLoupeFacet: ${marketLoupeFacet}`))

  const { address: marketStateFacet } = await deploy('MarketStateFacet', deployOpts)
  await verify(hre, { address: marketStateFacet })
  console.log(chalk.yellow(`✨ MarketStateFacet: ${marketStateFacet}`))

  const { address: marketLiquidityFacet } = await deploy('MarketLiquidityFacet', deployOpts)
  await verify(hre, { address: marketLiquidityFacet })
  console.log(chalk.yellow(`✨ MarketLiquidityFacet: ${marketLiquidityFacet}`))

  const { address: marketLiquidityLensFacet } = await deploy('MarketLiquidityLensFacet', deployOpts)
  await verify(hre, { address: marketLiquidityLensFacet })
  console.log(chalk.yellow(`✨ MarketLiquidityLensFacet: ${marketLiquidityLensFacet}`))

  const { address: marketTradeFacet } = await deploy('MarketTradeFacet', deployOpts)
  await verify(hre, { address: marketTradeFacet })
  console.log(chalk.yellow(`✨ MarketTradeFacet: ${marketTradeFacet}`))

  const { address: marketLiquidateFacet } = await deploy('MarketLiquidateFacet', deployOpts)
  await verify(hre, { address: marketLiquidateFacet })
  console.log(chalk.yellow(`✨ MarketLiquidateFacet: ${marketLiquidateFacet}`))

  const { address: marketSettleFacet } = await deploy('MarketSettleFacet', deployOpts)
  await verify(hre, { address: marketSettleFacet })
  console.log(chalk.yellow(`✨ MarketSettleFacet: ${marketSettleFacet}`))

  const {
    address: factory,
    args: factoryArgs,
    libraries: factoryLibraries
  } = await deploy('ChromaticMarketFactory', {
    ...deployOpts,
    args: [
      marketDiamondCutFacet,
      marketLoupeFacet,
      marketStateFacet,
      marketLiquidityFacet,
      marketLiquidityLensFacet,
      marketTradeFacet,
      marketLiquidateFacet,
      marketSettleFacet
    ],
    libraries: {
      MarketDeployerLib: marketDeployer
    }
  })
  await verify(hre, {
    address: factory,
    constructorArguments: factoryArgs,
    libraries: factoryLibraries
  })
  console.log(chalk.yellow(`✨ ChromaticMarketFactory: ${factory}`))

  const MarketFactory = await ethers.getContractFactory('ChromaticMarketFactory', {
    libraries: factoryLibraries
  })
  const marketFactory = MarketFactory.attach(factory) as ChromaticMarketFactory

  // deploy & set KeeperFeePayer

  const wrappedTokenAddress = WMNT[echainId] ?? WETH9[echainId].address

  const { address: keeperFeePayer, args: keeperFeePayerArgs } = await deploy('KeeperFeePayer', {
    ...deployOpts,
    args: [factory, swapRouterAddress, wrappedTokenAddress]
  })
  await verify(hre, {
    address: keeperFeePayer,
    constructorArguments: keeperFeePayerArgs
  })
  console.log(chalk.yellow(`✨ KeeperFeePayer: ${keeperFeePayer}`))

  await marketFactory.setKeeperFeePayer(keeperFeePayer, deployOpts)
  console.log(chalk.yellow('✨ Set KeeperFeePayer'))

  // deploy & set ChromaticVault

  const { address: vault, args: vaultArgs } = await deploy('ChromaticVault', {
    ...deployOpts,
    args: [factory, GELATO_ADDRESSES[echainId].automate, ZeroAddress]
  })
  await verify(hre, {
    address: vault,
    constructorArguments: vaultArgs
  })
  console.log(chalk.yellow(`✨ ChromaticVault: ${vault}`))

  await marketFactory.setVault(vault, deployOpts)
  console.log(chalk.yellow('✨ Set Vault'))
}

export default func

func.id = 'deploy_core' // id required to prevent reexecution
func.tags = ['core']
