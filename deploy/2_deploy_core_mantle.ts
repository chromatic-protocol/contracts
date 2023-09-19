import { verify } from '@chromatic/deploy/verify'
import { ChromaticMarketFactory__factory } from '@chromatic/typechain-types'
import chalk from 'chalk'
import type { DeployFunction } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
const MATE2_AUTOMATION_ADDRESS = '0x'
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { config, deployments, getNamedAccounts, ethers, network } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()



  console.log(chalk.yellow(`✨ Deploying... to ${network.name}`))

  const deployOpts = { from: deployer }
  const factory = await deployments.get('ChromaticMarketFactory')
  const { address: liquidator, args: liquidatorArgs } = await deploy(
    network.name === 'anvil' ? 'Mate2LiquidatorMock' : 'Mate2Liquidator',
    {
      ...deployOpts,
      args: [factory, MATE2_AUTOMATION_ADDRESS]
    }
  )
  await verify(hre, {
    address: liquidator,
    constructorArguments: liquidatorArgs
  })
  console.log(chalk.yellow(`✨ Mate2Liquidator: ${liquidator}`))
  const marketFactory = ChromaticMarketFactory__factory.connect(
    factory.address,
    await ethers.getSigner(deployer)
  )
  await marketFactory.setLiquidator(liquidator, deployOpts)
  console.log(chalk.yellow('✨ Set Liquidator'))
}

export default func

func.id = 'deploy_core_for_chain' // id required to prevent reexecution
func.tags = ['mantle']
