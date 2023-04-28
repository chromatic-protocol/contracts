import { BigNumber } from "ethers"
import { ethers } from "hardhat"
import { logDeployed } from "../log-utils"
import { OracleProviderMock } from "@usum/typechain-types"
import { deployContract } from "../utils"

export async function deploy(): Promise<OracleProviderMock> {
  return await deployContract<OracleProviderMock>("OracleProviderMock")
}
