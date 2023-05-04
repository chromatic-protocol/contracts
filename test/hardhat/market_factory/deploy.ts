import { BigNumber } from "ethers"
import { ethers } from "hardhat"
import { logDeployed } from "../log-utils"
import { USUMMarketFactory } from "@usum/typechain-types"
import { deployContract } from "../utils"
import {
  OracleProviderRegistryLib,
  SettlementTokenRegistryLib,
  MarketDeployerLib,
  KeeperFeePayerMock,
  USUMLiquidator,
  LpSlotSetLib,
} from "@usum/typechain-types"

export async function deploy(opsAddress: string, opsProxyFactory: string) {
  const [deployer] = await ethers.getSigners()

  const keeperFeePayer = await deployContract<KeeperFeePayerMock>(
    "KeeperFeePayerMock"
  )
  await (
    await deployer.sendTransaction({
      to: keeperFeePayer.address,
      value: ethers.utils.parseEther("5"),
    })
  ).wait()

  const liquidator = await deployContract<USUMLiquidator>("USUMLiquidator", {
    args: [opsAddress,opsProxyFactory],
  })

  const oracleProviderRegistryLib =
    await deployContract<OracleProviderRegistryLib>("OracleProviderRegistryLib")
  const settlementTokenRegistryLib =
    await deployContract<SettlementTokenRegistryLib>(
      "SettlementTokenRegistryLib"
    )

  const lpSlotSetLib = await deployContract<LpSlotSetLib>("LpSlotSetLib")
  const marketDeployerLib = await deployContract<MarketDeployerLib>(
    "MarketDeployerLib",
    {
      libraries: {
        LpSlotSetLib: lpSlotSetLib.address,
      },
    }
  )

  const marketFactory = await deployContract<USUMMarketFactory>(
    "USUMMarketFactory",
    {
      args: [liquidator.address,keeperFeePayer.address],
      libraries: {
        OracleProviderRegistryLib: oracleProviderRegistryLib.address,
        SettlementTokenRegistryLib: settlementTokenRegistryLib.address,
        MarketDeployerLib: marketDeployerLib.address,
      },
    }
  )

  return { marketFactory, keeperFeePayer, liquidator }
}
