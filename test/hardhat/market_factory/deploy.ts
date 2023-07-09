import {
  ChromaticLiquidator,
  ChromaticMarketFactory,
  ChromaticVault,
  KeeperFeePayerMock
} from '@chromatic/typechain-types'
import { CHAIN_ID, GELATO_ADDRESSES } from '@gelatonetwork/automate-sdk'
import { Contract, constants } from 'ethers'
import { ethers } from 'hardhat'
import { deployContract } from '../utils'

export async function deploy() {
  const [deployer] = await ethers.getSigners()

  const clbTokenDeployerLib = await deployContract<Contract>('CLBTokenDeployerLib')
  const marketDeployerLib = await deployContract<Contract>('MarketDeployerLib', {
    libraries: {
      CLBTokenDeployerLib: clbTokenDeployerLib.address
    }
  })

  const marketDiamondCutFacet = await deployContract<Contract>('MarketDiamondCutFacet')
  const marketLoupeFacet = await deployContract<Contract>('DiamondLoupeFacet')
  const marketStateFacet = await deployContract<Contract>('MarketStateFacet')
  const marketLiquidityFacet = await deployContract<Contract>('MarketLiquidityFacet')
  const marketTradeFacet = await deployContract<Contract>('MarketTradeFacet')
  const marketLiquidateFacet = await deployContract<Contract>('MarketLiquidateFacet')
  const marketSettleFacet = await deployContract<Contract>('MarketSettleFacet')
  
  const marketFactory = await deployContract<ChromaticMarketFactory>('ChromaticMarketFactory', {
    args: [
      marketDiamondCutFacet.address,
      marketLoupeFacet.address,
      marketStateFacet.address,
      marketLiquidityFacet.address,
      marketTradeFacet.address,
      marketLiquidateFacet.address,
      marketSettleFacet.address
    ],
    libraries: {
      MarketDeployerLib: marketDeployerLib.address
    }
  })

  const keeperFeePayer = await deployContract<KeeperFeePayerMock>('KeeperFeePayerMock', {
    args: [marketFactory.address]
  })
  await (await marketFactory.setKeeperFeePayer(keeperFeePayer.address)).wait()
  await (
    await deployer.sendTransaction({
      to: keeperFeePayer.address,
      value: ethers.utils.parseEther('5')
    })
  ).wait()

  const vault = await deployContract<ChromaticVault>('ChromaticVault', {
    args: [
      marketFactory.address,
      GELATO_ADDRESSES[CHAIN_ID.ARBITRUM_GOERLI].automate,
      constants.AddressZero
    ]
  })
  await (await marketFactory.setVault(vault.address)).wait()

  const liquidator = await deployContract<ChromaticLiquidator>('ChromaticLiquidator', {
    args: [
      marketFactory.address,
      GELATO_ADDRESSES[CHAIN_ID.ARBITRUM_GOERLI].automate,
      constants.AddressZero
    ]
  })
  await (await marketFactory.setLiquidator(liquidator.address)).wait()

  return { marketFactory, keeperFeePayer, liquidator }
}
