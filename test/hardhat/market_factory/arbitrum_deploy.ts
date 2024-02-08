import {
  ChromaticMarketFactory,
  ChromaticVault,
  FixedPriceSwapRouter,
  GelatoLiquidator,
  GelatoVaultEarningDistributor,
  IWETH9__factory,
  KeeperFeePayer
} from '@chromatic/typechain-types'
import { CHAIN_ID, GELATO_ADDRESSES } from '@gelatonetwork/automate-sdk'
import { Contract, ZeroAddress, parseEther } from 'ethers'
import { ethers } from 'hardhat'
import { deployContract } from '../utils'

const WETH: { [key: number]: string } = {
  421614: '0x980B62Da83eFf3D4576C647993b0c1D7faf17c73'
}

export async function deploy() {
  const [deployer] = await ethers.getSigners()

  const clbTokenDeployerLib = await deployContract<Contract>('CLBTokenDeployerLib')
  const marketDeployerLib = await deployContract<Contract>('MarketDeployerLib', {
    libraries: {
      CLBTokenDeployerLib: await clbTokenDeployerLib.getAddress()
    }
  })

  const marketDiamondCutFacet = await deployContract<Contract>('MarketDiamondCutFacet')
  const marketLoupeFacet = await deployContract<Contract>('DiamondLoupeFacet')
  const marketStateFacet = await deployContract<Contract>('MarketStateFacet')
  const marketAddLiquidityFacet = await deployContract<Contract>('MarketAddLiquidityFacet')
  const marketRemoveLiquidityFacet = await deployContract<Contract>('MarketRemoveLiquidityFacet')
  const marketLensFacet = await deployContract<Contract>('MarketLensFacet')
  const marketTradeOpenPositionFacet = await deployContract<Contract>(
    'MarketTradeOpenPositionFacet'
  )
  const marketTradeClosePositionFacet = await deployContract<Contract>(
    'MarketTradeClosePositionFacet'
  )
  const marketLiquidateFacet = await deployContract<Contract>('MarketLiquidateFacet')
  const marketSettleFacet = await deployContract<Contract>('MarketSettleFacet')

  const marketFactory = await deployContract<ChromaticMarketFactory>('ChromaticMarketFactory', {
    args: [
      await marketDiamondCutFacet.getAddress(),
      await marketLoupeFacet.getAddress(),
      await marketStateFacet.getAddress(),
      await marketAddLiquidityFacet.getAddress(),
      await marketRemoveLiquidityFacet.getAddress(),
      await marketLensFacet.getAddress(),
      await marketTradeOpenPositionFacet.getAddress(),
      await marketTradeClosePositionFacet.getAddress(),
      await marketLiquidateFacet.getAddress(),
      await marketSettleFacet.getAddress()
    ],
    libraries: {
      MarketDeployerLib: await marketDeployerLib.getAddress()
    }
  })

  const weth = IWETH9__factory.connect(WETH[CHAIN_ID.ARBSEPOLIA]).connect(deployer)
  const fixedPriceSwapRouter = await deployContract<FixedPriceSwapRouter>('FixedPriceSwapRouter', {
    args: [await weth.getAddress()]
  })
  await (await weth.deposit({ value: parseEther('5') })).wait()

  const keeperFeePayer = await deployContract<KeeperFeePayer>('KeeperFeePayer', {
    args: [
      await marketFactory.getAddress(),
      await fixedPriceSwapRouter.getAddress(),
      await weth.getAddress()
    ]
  })
  await (await marketFactory.updateKeeperFeePayer(keeperFeePayer.getAddress())).wait()
  await (await fixedPriceSwapRouter.addWhitelistedClient(keeperFeePayer.getAddress())).wait()

  console.log('gelato automate address', GELATO_ADDRESSES[CHAIN_ID.ARBSEPOLIA].automate)
  const distributor = await deployContract<GelatoVaultEarningDistributor>(
    'GelatoVaultEarningDistributor',
    {
      args: [await marketFactory.getAddress(), GELATO_ADDRESSES[CHAIN_ID.ARBSEPOLIA].automate]
    }
  )

  const vault = await deployContract<ChromaticVault>('ChromaticVault', {
    args: [await marketFactory.getAddress(), await distributor.getAddress()]
  })
  if ((await marketFactory.vault()) === ZeroAddress) {
    await (await marketFactory.setVault(vault.getAddress())).wait()
  }

  const liquidator = await deployContract<GelatoLiquidator>('GelatoLiquidator', {
    args: [await marketFactory.getAddress(), GELATO_ADDRESSES[CHAIN_ID.ARBSEPOLIA].automate]
  })
  if ((await marketFactory.liquidator()) === ZeroAddress) {
    await (await marketFactory.updateLiquidator(liquidator.getAddress())).wait()
  }

  return { marketFactory, keeperFeePayer, liquidator, fixedPriceSwapRouter }
}
