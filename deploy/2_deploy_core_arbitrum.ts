import { verify } from '@chromatic/deploy/verify'
import { ChromaticMarketFactory__factory } from '@chromatic/typechain-types'
import { GELATO_ADDRESSES } from '@gelatonetwork/automate-sdk'
import { WETH9 } from '@uniswap/smart-order-router'
import chalk from 'chalk'
import { ZeroAddress } from 'ethers'
import type { DeployFunction } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { config, deployments, getNamedAccounts, ethers, network } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const echainId: keyof typeof WETH9 =
    network.name === 'anvil' ? config.networks.arbitrum_goerli.chainId! : network.config.chainId!

  console.log(chalk.yellow(`✨ Deploying... to ${network.name}`))

  const deployOpts = { from: deployer }
  const factory = await deployments.get('ChromaticMarketFactory')
  const marketFactory = ChromaticMarketFactory__factory.connect(
    factory.address,
    await ethers.getSigner(deployer)
  )

  // deploy & set ChromaticVault
  const {address: distributor, args: distributorArgs} = await deploy('GelatoVaultEarningDistributor', {
    ...deployOpts,
    args: [factory.address, GELATO_ADDRESSES[echainId].automate, ZeroAddress]
  })
  await verify(hre, {
    address: distributor,
    constructorArguments: distributorArgs
  })
  console.log(chalk.yellow(`✨ GelatoVaultEarningDistributor: ${distributor}`))

  const { address: vault, args: vaultArgs } = await deploy('ChromaticVault', {
    ...deployOpts,
    args: [factory.address, distributor]
  })
  await verify(hre, {
    address: vault,
    constructorArguments: vaultArgs
  })
  console.log(chalk.yellow(`✨ ChromaticVault: ${vault}`))

  await marketFactory.setVault(vault, deployOpts)
  console.log(chalk.yellow('✨ Set Vault'))

  // deploy & set Liquidator
  
  const { address: liquidator, args: liquidatorArgs } = await deploy(
    network.name === 'anvil' ? 'GelatoLiquidatorMock' : 'GelatoLiquidator',
    {
      ...deployOpts,
      args: [factory.address, GELATO_ADDRESSES[echainId].automate, ZeroAddress]
    }
  )
  await verify(hre, {
    address: liquidator,
    constructorArguments: liquidatorArgs
  })
  console.log(chalk.yellow(`✨ GelatoLiquidator: ${liquidator}`))

  await marketFactory.setLiquidator(liquidator, deployOpts)
  console.log(chalk.yellow('✨ Set Liquidator'))
}

export default func

func.id = 'deploy_core_for_chain' // id required to prevent reexecution
func.tags = ['arbitrum']
