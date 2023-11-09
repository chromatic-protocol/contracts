import { ChromaticRouter } from '@chromatic/typechain-types'
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

  const { address: lensAddress, args: lensArgs } = await deploy('ChromaticLens', {
    from: deployer,
    args: [routerAddress]
  })
  console.log(chalk.yellow(`✨ ChromaticLens: ${lensAddress}`))

  const { address: referralStorageAddress, args: referralStorageArgs } = await deploy(
    'ReferralStorage',
    {
      from: deployer,
      args: [routerAddress]
    }
  )
  console.log(chalk.yellow(`✨ ReferralStorage: ${referralStorageAddress}`))

  const RouterFactory = await ethers.getContractFactory('ChromaticRouter')
  const router = RouterFactory.attach(routerAddress) as ChromaticRouter

  await router.setReferralStorage(referralStorageAddress)
  console.log(chalk.yellow('✨ Set ReferralStorage'))
}

export default func

func.id = 'deploy_periphery' // id required to prevent reexecution
func.tags = ['periphery']
