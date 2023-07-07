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
