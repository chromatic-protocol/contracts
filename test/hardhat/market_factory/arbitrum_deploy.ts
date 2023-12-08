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
import { ChainId } from '@uniswap/sdk-core'
import { WETH9 } from '@uniswap/smart-order-router'
import { Contract, ZeroAddress, parseEther } from 'ethers'
import { ethers } from 'hardhat'
import { deployContract } from '../utils'

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
  const marketLiquidityFacet = await deployContract<Contract>('MarketLiquidityFacet')
  const marketLensFacet = await deployContract<Contract>('MarketLensFacet')
  const marketTradeFacet = await deployContract<Contract>('MarketTradeFacet')
  const marketLiquidateFacet = await deployContract<Contract>('MarketLiquidateFacet')
  const marketSettleFacet = await deployContract<Contract>('MarketSettleFacet')

  const marketFactory = await deployContract<ChromaticMarketFactory>('ChromaticMarketFactory', {
    args: [
      await marketDiamondCutFacet.getAddress(),
      await marketLoupeFacet.getAddress(),
      await marketStateFacet.getAddress(),
      await marketLiquidityFacet.getAddress(),
      await marketLensFacet.getAddress(),
      await marketTradeFacet.getAddress(),
      await marketLiquidateFacet.getAddress(),
      await marketSettleFacet.getAddress()
    ],
    libraries: {
      MarketDeployerLib: await marketDeployerLib.getAddress()
    }
  })

  const weth = IWETH9__factory.connect(WETH9[ChainId.ARBITRUM_GOERLI].address).connect(deployer)
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
  await (await marketFactory.setKeeperFeePayer(keeperFeePayer.getAddress())).wait()
  await (await fixedPriceSwapRouter.addWhitelistedClient(keeperFeePayer.getAddress())).wait()

  console.log('gelato automate address', GELATO_ADDRESSES[CHAIN_ID.ARBITRUM_GOERLI].automate)
  const distributor = await deployContract<GelatoVaultEarningDistributor>(
    'GelatoVaultEarningDistributor',
    {
      args: [
        await marketFactory.getAddress(),
        GELATO_ADDRESSES[CHAIN_ID.ARBITRUM_GOERLI].automate,
        ZeroAddress
      ]
    }
  )

  const vault = await deployContract<ChromaticVault>('ChromaticVault', {
    args: [await marketFactory.getAddress(), await distributor.getAddress()]
  })
  if ((await marketFactory.vault()) === ZeroAddress) {
    await (await marketFactory.setVault(vault.getAddress())).wait()
  }

  const liquidator = await deployContract<GelatoLiquidator>('GelatoLiquidator', {
    args: [
      await marketFactory.getAddress(),
      GELATO_ADDRESSES[CHAIN_ID.ARBITRUM_GOERLI].automate,
      ZeroAddress
    ]
  })
  if ((await marketFactory.liquidator()) === ZeroAddress) {
    await (await marketFactory.setLiquidator(liquidator.getAddress())).wait()
  }

  return { marketFactory, keeperFeePayer, liquidator, fixedPriceSwapRouter }
}
