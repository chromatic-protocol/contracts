import chalk from 'chalk'
import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const { address: marketFactoryAddress } = await deployments.get('ChromaticMarketFactory')

  const { address: routerAddress } = await deploy('ChromaticRouter', {
    from: deployer,
    args: [marketFactoryAddress]
  })
  console.log(chalk.yellow(`✨ ChromaticRouter: ${routerAddress}`))

  const { address: lensAddress } = await deploy('ChromaticLens', {
    from: deployer,
    args: [routerAddress]
  })
  console.log(chalk.yellow(`✨ ChromaticLens: ${lensAddress}`))
}

export default func

func.id = 'deploy_periphery' // id required to prevent reexecution
func.tags = ['periphery']
