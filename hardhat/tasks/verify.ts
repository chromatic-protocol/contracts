import { ChromaticRouter, IChromaticMarketFactory__factory } from '@chromatic/typechain-types'
import chalk from 'chalk'
import { subtask, task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'

task('verify:all').setAction(
  async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment): Promise<any> => {
    await hre.run('verify:core')
    await hre.run('verify:periphery')
  }
)

task('verify:core').setAction(
  async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment): Promise<any> => {
    const { deployments, network } = hre

    const marketDiamondCutFacet = await deployments.get('MarketDiamondCutFacet')
    await verify(hre, { address: marketDiamondCutFacet.address })
    console.log(chalk.yellow(`✨ verify MarketDiamondCutFacet`))

    const marketLoupeFacet = await deployments.get('DiamondLoupeFacet')
    await verify(hre, { address: marketLoupeFacet.address })
    console.log(chalk.yellow(`✨ verify DiamondLoupeFacet`))

    const marketStateFacet = await deployments.get('MarketStateFacet')
    await verify(hre, { address: marketStateFacet.address })
    console.log(chalk.yellow(`✨ verify MarketStateFacet`))

    const marketAddLiquidityFacet = await deployments.get('MarketAddLiquidityFacet')
    await verify(hre, { address: marketAddLiquidityFacet.address })
    console.log(chalk.yellow(`✨ verify MarketAddLiquidityFacet`))

    const marketRemoveLiquidityFacet = await deployments.get('MarketRemoveLiquidityFacet')
    await verify(hre, { address: marketRemoveLiquidityFacet.address })
    console.log(chalk.yellow(`✨ verify MarketRemoveLiquidityFacet`))

    const marketLensFacet = await deployments.get('MarketLensFacet')
    await verify(hre, { address: marketLensFacet.address })
    console.log(chalk.yellow(`✨ verify MarketLensFacet`))

    const marketTradeOpenPositionFacet = await deployments.get('MarketTradeOpenPositionFacet')
    await verify(hre, { address: marketTradeOpenPositionFacet.address })
    console.log(chalk.yellow(`✨ verify MarketTradeOpenPositionFacet`))

    const marketTradeClosePositionFacet = await deployments.get('MarketTradeClosePositionFacet')
    await verify(hre, { address: marketTradeClosePositionFacet.address })
    console.log(chalk.yellow(`✨ verify MarketTradeClosePositionFacet`))

    const marketLiquidateFacet = await deployments.get('MarketLiquidateFacet')
    await verify(hre, { address: marketLiquidateFacet.address })
    console.log(chalk.yellow(`✨ verify MarketLiquidateFacet`))

    const marketSettleFacet = await deployments.get('MarketSettleFacet')
    await verify(hre, { address: marketSettleFacet.address })
    console.log(chalk.yellow(`✨ verify MarketSettleFacet`))

    const factory = await deployments.get('ChromaticMarketFactory')
    await verify(hre, {
      address: factory.address,
      constructorArguments: factory.args,
      libraries: factory.libraries
    })
    console.log(chalk.yellow(`✨ verify ChromaticMarketFactory`))

    const keeperFeePayer = await deployments.get('KeeperFeePayer')
    await verify(hre, {
      address: keeperFeePayer.address,
      constructorArguments: keeperFeePayer.args
    })
    console.log(chalk.yellow(`✨ verify KeeperFeePayer`))

    const vault = await deployments.get('ChromaticVault')
    await verify(hre, {
      address: vault.address,
      constructorArguments: vault.args
    })
    console.log(chalk.yellow(`✨ verify ChromaticVault`))

    const signers = await hre.ethers.getSigners()
    const marketFactory = IChromaticMarketFactory__factory.connect(factory.address, signers[0])
    const marketAddresses = await marketFactory.getMarkets()

    if (marketAddresses.length > 0) {
      await verify(hre, {
        address: marketAddresses[0],
        constructorArguments: [marketDiamondCutFacet.address],
        libraries: {
          CLBTokenDeployerLib: (await deployments.get('CLBTokenDeployerLib')).address
        }
      })
      console.log(chalk.yellow(`✨ verify ChromaticMarket`))
    }

    switch (true) {
      case /^arbitrum/.test(network.name):
        await hre.run('verify:core:arbitrum')
        break
      case /^mantle/.test(network.name):
        await hre.run('verify:core:mantle')
        break
    }
  }
)

subtask('verify:core:arbitrum').setAction(
  async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment): Promise<any> => {
    const { deployments } = hre

    const distributor = await deployments.get('GelatoVaultEarningDistributor')
    await verify(hre, {
      address: distributor.address,
      constructorArguments: distributor.args
    })
    console.log(chalk.yellow(`✨ verify GelatoVaultEarningDistributor`))

    const liquidator = await deployments.get('GelatoLiquidator')
    await verify(hre, {
      address: liquidator.address,
      constructorArguments: liquidator.args
    })
    console.log(chalk.yellow(`✨ verify GelatoLiquidator`))
  }
)

subtask('verify:core:mantle').setAction(
  async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment): Promise<any> => {
    const { deployments } = hre

    const distributor = await deployments.get('Mate2VaultEarningDistributor')
    await verify(hre, {
      address: distributor.address,
      constructorArguments: distributor.args
    })
    console.log(chalk.yellow(`✨ verify Mate2VaultEarningDistributor`))

    const liquidator = await deployments.get('Mate2Liquidator')
    await verify(hre, {
      address: liquidator.address,
      constructorArguments: liquidator.args
    })
    console.log(chalk.yellow(`✨ verify Mate2Liquidator`))

    const marketSettlement = await deployments.get('Mate2MarketSettlement')
    await verify(hre, {
      address: marketSettlement.address,
      constructorArguments: marketSettlement.args
    })
    console.log(chalk.yellow(`✨ verify Mate2MarketSettlement`))
  }
)

task('verify:periphery').setAction(
  async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment): Promise<any> => {
    const { deployments, ethers } = hre

    const router = await deployments.get('ChromaticRouter')
    await verify(hre, {
      address: router.address,
      constructorArguments: router.args
    })
    console.log(chalk.yellow(`✨ verify ChromaticRouter`))

    const ChromaticRouter = await ethers.getContractFactory('ChromaticRouter')
    const chromatiRouter = ChromaticRouter.attach(router.address) as ChromaticRouter
    const accountAddress = await chromatiRouter.accountBase()
    await verify(hre, {
      address: accountAddress
    })
    console.log(chalk.yellow(`✨ verify ChromaticRouter.accountBase`))

    const lens = await deployments.get('ChromaticLens')
    await verify(hre, {
      address: lens.address,
      constructorArguments: lens.args
    })
    console.log(chalk.yellow(`✨ verify ChromaticLens`))
  }
)

async function verify(hre: HardhatRuntimeEnvironment, args: any) {
  if (!hre.network.name.startsWith('anvil')) {
    for (let i = 0; i < 5; i++) {
      try {
        await hre.run('verify:verify', args)
        return
      } catch (e) {
        console.error(e)
      }
    }
  }
}
