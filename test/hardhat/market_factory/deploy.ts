import { BigNumber } from "ethers"
import { ethers } from "hardhat"
import { logDeployed } from "../log-utils"
import { USUMMarketFactory } from "@usum/typechain-types"
import { Contract } from "ethers"
import { deployContract } from "../utils"
import {
  OracleRegistry,
  KeeperFeePayerMock,
  USUMLiquidator,
  LpSlotSetLib,
} from "@usum/typechain-types"

export async function deploy(opsAddress: string) {
  const [deployer] = await ethers.getSigners()

  const oracleRegistry = await deployContract<OracleRegistry>("OracleRegistry")
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
        oracleRegistry.address,
        keeperFeePayer.address,
        liquidator.address,
      ],
      libraries: { LpSlotSetLib: lpSlotSetLib.address },
    }
  )

  return { oracleRegistry, marketFactory, keeperFeePayer, liquidator }
}
