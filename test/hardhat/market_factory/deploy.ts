import { BigNumber } from "ethers"
import { ethers } from "hardhat"
import { logDeployed } from "../log-utils"
import { USUMMarketFactory } from "@usum/typechain-types"
import { Contract } from "ethers"
import { deployContract } from "../utils"
import {
  OracleProviderRegistry,
  KeeperFeePayerMock,
  USUMLiquidator,
  LpSlotSetLib,
} from "@usum/typechain-types"

export async function deploy(opsAddress: string) {
  const [deployer] = await ethers.getSigners()

  const oracleProviderRegistry = await deployContract<OracleProviderRegistry>("OracleProviderRegistry")
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
    args: [opsAddress],
  })

  const lpSlotSetLib = await deployContract<LpSlotSetLib>("LpSlotSetLib")

  const marketFactory = await deployContract<USUMMarketFactory>(
    "USUMMarketFactory",
    {
      args: [
        oracleProviderRegistry.address,
        keeperFeePayer.address,
        liquidator.address,
      ],
      libraries: { LpSlotSetLib: lpSlotSetLib.address },
    }
  )

  return { oracleProviderRegistry, marketFactory, keeperFeePayer, liquidator }
}
