import { verify } from '@chromatic/deploy/verify'
import chalk from 'chalk'
import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const { address: marketFactoryAddress } = await deployments.get('ChromaticMarketFactory')

  const { address: routerAddress, args: routerArgs } = await deploy('ChromaticRouter', {
    from: deployer,
    args: [marketFactoryAddress]
  })
  await verify(hre, {
    address: routerAddress,
    constructorArguments: routerArgs
  })
  console.log(chalk.yellow(`✨ ChromaticRouter: ${routerAddress}`))

  const { address: lensAddress, args: lensArgs } = await deploy('ChromaticLens', {
    from: deployer,
    args: [routerAddress]
  })
  await verify(hre, {
    address: lensAddress,
    constructorArguments: lensArgs
  })
  console.log(chalk.yellow(`✨ ChromaticLens: ${lensAddress}`))
}

export default func

func.id = 'deploy_periphery' // id required to prevent reexecution
func.tags = ['periphery']
