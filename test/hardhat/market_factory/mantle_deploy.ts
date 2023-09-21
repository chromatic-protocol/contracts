import {
  ChromaticMarketFactory,
  ChromaticVault,
  Mate2Liquidator,
  KeeperFeePayerMock,
  IMate2AutomationRegistry__factory
} from '@chromatic/typechain-types'
import { Mate2VaultEarningDistributor } from '@chromatic/typechain-types/contracts/core/automation/Mate2VaultEarningDistributor'
import { CHAIN_ID, GELATO_ADDRESSES } from '@gelatonetwork/automate-sdk'
import { Contract, ZeroAddress, parseEther } from 'ethers'
import { ethers } from 'hardhat'
import { deployContract } from '../utils'
import { MATE2_AUTOMATION_ADDRESS } from '../../../deploy/2_deploy_core_mantle'

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
  const marketLiquidityLensFacet = await deployContract<Contract>('MarketLiquidityLensFacet')
  const marketTradeFacet = await deployContract<Contract>('MarketTradeFacet')
  const marketLiquidateFacet = await deployContract<Contract>('MarketLiquidateFacet')
  const marketSettleFacet = await deployContract<Contract>('MarketSettleFacet')

  const marketFactory = await deployContract<ChromaticMarketFactory>('ChromaticMarketFactory', {
    args: [
      await marketDiamondCutFacet.getAddress(),
      await marketLoupeFacet.getAddress(),
      await marketStateFacet.getAddress(),
      await marketLiquidityFacet.getAddress(),
      await marketLiquidityLensFacet.getAddress(),
      await marketTradeFacet.getAddress(),
      await marketLiquidateFacet.getAddress(),
      await marketSettleFacet.getAddress()
    ],
    libraries: {
      MarketDeployerLib: await marketDeployerLib.getAddress()
    }
  })

  const keeperFeePayer = await deployContract<KeeperFeePayerMock>('KeeperFeePayerMock', {
    args: [await marketFactory.getAddress()]
  })
  await (await marketFactory.setKeeperFeePayer(keeperFeePayer.getAddress())).wait()
  await (
    await deployer.sendTransaction({
      to: keeperFeePayer.getAddress(),
      value: parseEther('5')
    })
  ).wait()

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
  await (await mate2automate.addWhitelistedRegistrar(distributor)).wait()

  const vault = await deployContract<ChromaticVault>('ChromaticVault', {
    args: [await marketFactory.getAddress(), await distributor.getAddress()]
  })
  await (await marketFactory.setVault(vault.getAddress())).wait()

  const liquidator = await deployContract<Mate2Liquidator>('Mate2Liquidator', {
    args: [await marketFactory.getAddress(), MATE2_AUTOMATION_ADDRESS]
  })
  await (await marketFactory.setLiquidator(liquidator.getAddress())).wait()

  return { marketFactory, keeperFeePayer, liquidator }
}
