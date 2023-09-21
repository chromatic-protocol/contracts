import { verify } from '@chromatic/deploy/verify'
import {
  ChromaticMarketFactory__factory,
  IMate2AutomationRegistry__factory
} from '@chromatic/typechain-types'
import chalk from 'chalk'
import type { DeployFunction } from 'hardhat-deploy/types'
import type { HardhatRuntimeEnvironment } from 'hardhat/types'
export const MATE2_AUTOMATION_ADDRESS = '0xe1Fd27F4390DcBE165f4D60DBF821e4B9Bb02dEd'
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { config, deployments, getNamedAccounts, ethers, network } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  console.log(chalk.yellow(`✨ Deploying... to ${network.name}`))

  const deployOpts = { from: deployer }
  const factory = await deployments.get('ChromaticMarketFactory')
  const marketFactory = ChromaticMarketFactory__factory.connect(
    factory.address,
    await ethers.getSigner(deployer)
  )

  const { address: distributor, args: distributorArgs } = await deploy(
    'Mate2VaultEarningDistributor',
    {
      ...deployOpts,
      args: [factory.address, MATE2_AUTOMATION_ADDRESS]
    }
  )

  await verify(hre, {
    address: distributor,
    constructorArguments: distributorArgs
  })
  console.log(chalk.yellow(`✨ Mate2VaultEarningDistributor: ${distributor}`))
  const mate2automate = IMate2AutomationRegistry__factory.connect(
    MATE2_AUTOMATION_ADDRESS,
    await ethers.getSigner(deployer)
  )
  await (await mate2automate.addWhitelistedRegistrar(distributor)).wait()
  const { address: vault, args: vaultArgs } = await deploy('ChromaticVault', {
    ...deployOpts,
    args: [factory.address, distributor]
  })
  await verify(hre, {
    address: vault,
    constructorArguments: vaultArgs
  })
  await marketFactory.setVault(vault, deployOpts)
  console.log(chalk.yellow(`✨ ChromaticVault: ${vault}`))

  const { address: liquidator, args: liquidatorArgs } = await deploy(
    network.name === 'anvil' ? 'Mate2LiquidatorMock' : 'Mate2Liquidator',
    {
      ...deployOpts,
      args: [factory.address, MATE2_AUTOMATION_ADDRESS]
    }
  )

  await verify(hre, {
    address: liquidator,
    constructorArguments: liquidatorArgs
  })
  console.log(chalk.yellow(`✨ Mate2Liquidator: ${liquidator}`))

  await marketFactory.setLiquidator(liquidator, deployOpts)
  console.log(chalk.yellow('✨ Set Liquidator'))
}

export default func

func.id = 'deploy_core_for_chain' // id required to prevent reexecution
func.tags = ['mantle']
