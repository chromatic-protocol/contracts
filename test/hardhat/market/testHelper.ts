import { loadFixture } from "@nomicfoundation/hardhat-network-helpers"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { BigNumber } from "ethers"
import { ethers } from "hardhat"
import { deploy as marketDeploy } from "../deployMarket"
import { logYellow } from "../log-utils"

export const prepareMarketTest = async () => {
  async function addLiquidity(_amount?: BigNumber, _feeSlotKey?: number) {
    const approveTx = await settlementToken
      .connect(tester)
      .approve(usumRouter.address, ethers.constants.MaxUint256)
    await approveTx.wait()

    const amount = _amount ?? ethers.utils.parseEther("100")
    const feeSlotKey = _feeSlotKey ?? 1

    const addLiqTx = await usumRouter.connect(tester).addLiquidity(
      market.address,
      feeSlotKey,
      amount,
      tester.address,
      ethers.constants.MaxUint256 // deadline
    )
    await addLiqTx.wait()
    return {
      amount,
      feeSlotKey,
    }
  }

  async function faucet(account: SignerWithAddress) {
    const faucetTx = await settlementToken
      .connect(account)
      .faucet(ethers.utils.parseEther("1000000"))
    await faucetTx.wait()
  }
  const {
    marketFactory,
    keeperFeePayer,
    liquidator,
    oracleProvider,
    market,
    usumRouter,
    accountFactory,
    settlementToken,
    gelato,
  } = await loadFixture(marketDeploy)
  const [owner, tester, trader] = await ethers.getSigners()
  console.log("owner", owner.address)

  await faucet(tester)
  await faucet(trader)

  const createAccountTx = await accountFactory.connect(trader).createAccount()
  await createAccountTx.wait()

  const traderAccountAddr = await usumRouter.connect(trader).getAccount()
  const traderAccount = await ethers.getContractAt("Account", traderAccountAddr)

  logYellow(`\ttraderAccount: ${traderAccount}`)

  const transferTx = await settlementToken
    .connect(trader)
    .transfer(traderAccountAddr, ethers.utils.parseEther("1000000"))
  await transferTx.wait()

  const traderRouter = usumRouter.connect(trader)
  await (
    await settlementToken
      .connect(trader)
      .approve(traderRouter.address, ethers.constants.MaxUint256)
  ).wait()

  async function updatePrice(price: number) {
    await (
      await oracleProvider.increaseVersion(
        BigNumber.from(price.toString()).mul(10 ** 8)
      )
    ).wait()
  }

  return {
    oracleProvider,
    marketFactory,
    settlementToken,
    market,
    accountFactory,
    usumRouter,
    owner,
    tester,
    trader,
    liquidator,
    keeperFeePayer,
    traderAccount,
    traderRouter,
    gelato,
    // addLiquidity,
    // updatePrice,
  }
}

export const helpers = function (
  testData: Awaited<ReturnType<typeof prepareMarketTest>>
) {
  const { oracleProvider, settlementToken, tester, usumRouter, market } =
    testData
  async function updatePrice(price: number) {
    await (
      await oracleProvider.increaseVersion(
        BigNumber.from(price.toString()).mul(10 ** 8)
      )
    ).wait()
  }

  async function addLiquidity(_amount?: BigNumber, _feeSlotKey?: number) {
    const approveTx = await settlementToken
      .connect(tester)
      .approve(usumRouter.address, ethers.constants.MaxUint256)
    await approveTx.wait()

    const amount = _amount ?? ethers.utils.parseEther("100")
    const feeSlotKey = _feeSlotKey ?? 1

    const addLiqTx = await usumRouter.connect(tester).addLiquidity(
      market.address,
      feeSlotKey,
      amount,
      tester.address,
      ethers.constants.MaxUint256 // deadline
    )
    await addLiqTx.wait()
    return {
      amount,
      feeSlotKey,
    }
  }
  async function awaitTx(response: any) {
    response = await response
    if (typeof response.wait === "function") return await response.wait()
    return response
  }

  return {
    updatePrice,
    addLiquidity,
    awaitTx,
  }
}
