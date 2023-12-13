import {
  ChromaticMarketFactory,
  ChromaticVault,
  FixedPriceSwapRouter,
  IMate2AutomationRegistry__factory,
  IOwnable__factory,
  IWETH9__factory,
  KeeperFeePayer,
  Mate2Liquidator
} from '@chromatic/typechain-types'
import { Mate2VaultEarningDistributor } from '@chromatic/typechain-types/contracts/core/automation/Mate2VaultEarningDistributor'
import { Contract, ZeroAddress, parseEther } from 'ethers'
import { ethers } from 'hardhat'

import { deployContract } from '../utils'

const WMNT_ADDRESS = '0xea12be2389c2254baad383c6ed1fa1e15202b52a'
const MATE2_AUTOMATION_ADDRESS = '0xA58c89bB5a9EA4F1ceA61fF661ED2342D845441B'

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

  const wmnt = IWETH9__factory.connect(WMNT_ADDRESS).connect(deployer)
  const fixedPriceSwapRouter = await deployContract<FixedPriceSwapRouter>('FixedPriceSwapRouter', {
    args: [WMNT_ADDRESS]
  })
  await (await wmnt.deposit({ value: parseEther('5') })).wait()

  const keeperFeePayer = await deployContract<KeeperFeePayer>('KeeperFeePayer', {
    args: [
      await marketFactory.getAddress(),
      await fixedPriceSwapRouter.getAddress(),
      await wmnt.getAddress()
    ]
  })
  await (await marketFactory.updateKeeperFeePayer(keeperFeePayer.getAddress())).wait()
  await (await fixedPriceSwapRouter.addWhitelistedClient(keeperFeePayer.getAddress())).wait()

  const distributor = await deployContract<Mate2VaultEarningDistributor>(
    'Mate2VaultEarningDistributor',
    {
      args: [await marketFactory.getAddress(), MATE2_AUTOMATION_ADDRESS]
    }
  )
  const mate2automate = IMate2AutomationRegistry__factory.connect(
    MATE2_AUTOMATION_ADDRESS,
    deployer
  )

  console.log('add mate2 automate whitelist target : ', await distributor.getAddress())

  console.log(
    'mate2 owner',
    await IOwnable__factory.connect(
      await mate2automate.getAddress(),
      await ethers.getSigner(deployer.address)
    ).owner()
  )

  try {
    await (await mate2automate.addWhitelistedRegistrar(await distributor.getAddress())).wait()
  } catch (e) {
    console.log('add to whitelist failed')
  }

  const vault = await deployContract<ChromaticVault>('ChromaticVault', {
    args: [await marketFactory.getAddress(), await distributor.getAddress()]
  })
  if ((await marketFactory.vault()) === ZeroAddress) {
    await (await marketFactory.setVault(vault.getAddress())).wait()
  }

  const liquidator = await deployContract<Mate2Liquidator>('Mate2Liquidator', {
    args: [await marketFactory.getAddress(), MATE2_AUTOMATION_ADDRESS]
  })
  try {
    await (await mate2automate.addWhitelistedRegistrar(await liquidator.getAddress())).wait()
  } catch (e) {
    console.log('add to whitelist failed(Mate2Liquidator)')
  }

  if ((await marketFactory.liquidator()) === ZeroAddress) {
    await (await marketFactory.updateLiquidator(liquidator.getAddress())).wait()
  }

  return { marketFactory, keeperFeePayer, liquidator, fixedPriceSwapRouter }
}
