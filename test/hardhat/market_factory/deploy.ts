import {
  KeeperFeePayerMock,
  ChromaticLiquidator,
  ChromaticMarketFactory,
  ChromaticVault
} from '@chromatic/typechain-types'
import { Contract } from 'ethers'
import { ethers } from 'hardhat'
import { deployContract } from '../utils'

export async function deploy(opsAddress: string, opsProxyFactory: string) {
  const [deployer] = await ethers.getSigners()

  const oracleProviderRegistryLib = await deployContract<Contract>('OracleProviderRegistryLib')
  const settlementTokenRegistryLib = await deployContract<Contract>('SettlementTokenRegistryLib')

  const liquidityPoolLib = await deployContract<Contract>('LiquidityPoolLib')
  const clbTokenDeployerLib = await deployContract<Contract>('CLBTokenDeployerLib')
  const marketDeployerLib = await deployContract<Contract>('MarketDeployerLib', {
    libraries: {
      LiquidityPoolLib: liquidityPoolLib.address,
      CLBTokenDeployerLib: clbTokenDeployerLib.address
    }
  })

  const marketFactory = await deployContract<ChromaticMarketFactory>('ChromaticMarketFactory', {
    libraries: {
      OracleProviderRegistryLib: oracleProviderRegistryLib.address,
      SettlementTokenRegistryLib: settlementTokenRegistryLib.address,
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
    args: [marketFactory.address, opsAddress, opsProxyFactory]
  })
  await (await marketFactory.setVault(vault.address)).wait()

  const liquidator = await deployContract<ChromaticLiquidator>('ChromaticLiquidator', {
    args: [marketFactory.address, opsAddress, opsProxyFactory]
  })
  await (await marketFactory.setLiquidator(liquidator.address)).wait()

  return { marketFactory, keeperFeePayer, liquidator }
}
