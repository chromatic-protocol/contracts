import { CLBToken__factory } from '@chromatic/typechain-types'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { BigNumber } from 'ethers'
import { ethers } from 'hardhat'
import { deploy as marketDeploy } from '../deployMarket'
import { logYellow } from '../log-utils'

export const prepareMarketTest = async () => {
  async function faucet(account: SignerWithAddress) {
    const faucetTx = await settlementToken
      .connect(account)
      .faucet(ethers.utils.parseEther('1000000000'))
    await faucetTx.wait()
  }
  const {
    marketFactory,
    keeperFeePayer,
    liquidator,
    oracleProvider,
    market,
    chromaticRouter,
    settlementToken,
    gelato,
    lens
  } = await loadFixture(marketDeploy)
  const [owner, tester, trader] = await ethers.getSigners()
  console.log('owner', owner.address)

  const approveTx = await settlementToken
    .connect(tester)
    .approve(chromaticRouter.address, ethers.constants.MaxUint256)
  await approveTx.wait()

  await faucet(tester)
  await faucet(trader)

  const createAccountTx = await chromaticRouter.connect(trader).createAccount()
  await createAccountTx.wait()

  const traderAccountAddr = await chromaticRouter.connect(trader).getAccount()
  const traderAccount = await ethers.getContractAt('ChromaticAccount', traderAccountAddr)

  logYellow(`\ttraderAccount: ${traderAccount}`)

  const transferTx = await settlementToken
    .connect(trader)
    .transfer(traderAccountAddr, ethers.utils.parseEther('1000000'))
  await transferTx.wait()

  const traderRouter = chromaticRouter.connect(trader)
  await (
    await settlementToken.connect(trader).approve(traderRouter.address, ethers.constants.MaxUint256)
  ).wait()

  async function updatePrice(price: number) {
    await (
      await oracleProvider.increaseVersion(BigNumber.from(price.toString()).mul(10 ** 8))
    ).wait()
  }

  const clbToken = CLBToken__factory.connect(await market.clbToken(), tester)

  return {
    oracleProvider,
    marketFactory,
    settlementToken,
    market,
    chromaticRouter,
    owner,
    tester,
    trader,
    liquidator,
    keeperFeePayer,
    traderAccount,
    traderRouter,
    gelato,
    clbToken,
    lens
    // addLiquidity,
    // updatePrice,
  }
}

export const helpers = function (testData: Awaited<ReturnType<typeof prepareMarketTest>>) {
  const { oracleProvider, settlementToken, tester, chromaticRouter, market, traderRouter } =
    testData
  async function updatePrice(price: number) {
    await (
      await oracleProvider.increaseVersion(BigNumber.from(price.toString()).mul(10 ** 8))
    ).wait()
  }

  async function openPosition({
    takerMargin = ethers.utils.parseEther('10'),
    makerMargin = ethers.utils.parseEther('50'),
    qty = 10 ** 4,
    leverage = 500, // 5 x
    maxAllowFeeRate = 1
  }: {
    takerMargin?: BigNumber
    makerMargin?: BigNumber
    qty?: number
    leverage?: number
    maxAllowFeeRate?: number
  } = {}) {
    const openPositionTx = await traderRouter.openPosition(
      market.address,
      qty,
      leverage,
      takerMargin, // losscut 1 token
      makerMargin, // profit stop 10 token,
      makerMargin.mul(maxAllowFeeRate.toString()).div(100) // maxAllowFee (1% * makerMargin)
    )
    const receipt = await openPositionTx.wait()
    return {
      receipt,
      makerMargin,
      takerMargin,
      qty,
      leverage
    }
  }

  async function closePosition(positionId: BigNumber) {
    const closePositionTx = await traderRouter.closePosition(market.address, positionId)
    const receipt = await closePositionTx.wait()

    return {
      receipt,
      blockNumber: closePositionTx.blockNumber,
      blockHash: receipt.blockHash,
      transactionHash: closePositionTx.hash,
      timestamp: closePositionTx.timestamp
    }
  }

  async function getLpReceiptIds() {
    return chromaticRouter.connect(tester).getLpReceiptIds(market.address)
  }

  async function addLiquidityTx(amount: BigNumber, feeBinKey: number) {
    return chromaticRouter
      .connect(tester)
      .addLiquidity(market.address, feeBinKey, amount, tester.address)
  }

  async function addLiquidity(_amount?: BigNumber, _feeBinKey?: number) {
    const amount = _amount ?? ethers.utils.parseEther('100')
    const feeBinKey = _feeBinKey ?? 1

    const addLiqTx = await addLiquidityTx(amount, feeBinKey)
    await addLiqTx.wait()
    return {
      amount,
      feeBinKey
    }
  }

  async function claimPosition(positionId: BigNumber) {
    const claimTx = await traderRouter.claimPosition(market.address, positionId)
    return claimTx.wait()
  }

  async function addLiquidityBatch(amounts: BigNumber[], feeRates: number[]) {
    return chromaticRouter.connect(tester).addLiquidityBatch(
      market.address,
      feeRates,
      amounts,
      feeRates.map((_) => tester.address)
    )
  }

  async function claimLiquidity(receiptId: BigNumber) {
    return chromaticRouter.connect(tester).claimLiquidity(market.address, receiptId)
  }

  async function claimLiquidityBatch(receiptIds: BigNumber[]) {
    return chromaticRouter.connect(tester).claimLiquidityBatch(market.address, receiptIds)
  }

  async function removeLiquidity(clbTokenAmount: BigNumber, feeRate: number) {
    await (
      await testData.clbToken.connect(tester).setApprovalForAll(chromaticRouter.address, true)
    ).wait()
    return chromaticRouter
      .connect(tester)
      .removeLiquidity(market.address, feeRate, clbTokenAmount, tester.address)
  }

  async function removeLiquidityBatch(clbTokenAmounts: BigNumber[], feeRates: number[]) {
    return chromaticRouter.connect(tester).removeLiquidityBatch(
      market.address,
      feeRates,
      clbTokenAmounts,
      feeRates.map((_) => tester.address)
    )
  }

  async function withdrawLiquidity(receiptId: BigNumber) {
    return chromaticRouter.connect(tester).withdrawLiquidity(market.address, receiptId)
  }

  async function withdrawLiquidityBatch(receiptIds: BigNumber[]) {
    return chromaticRouter.connect(tester).withdrawLiquidityBatch(market.address, receiptIds)
  }

  async function awaitTx(response: any) {
    response = await response
    if (typeof response.wait === 'function') return await response.wait()
    return response
  }

  async function settle() {
    return (await market.settle()).wait()
  }

  return {
    updatePrice,
    getLpReceiptIds,
    addLiquidityBatch,
    addLiquidityTx,
    addLiquidity,
    awaitTx,
    openPosition,
    closePosition,
    claimPosition,
    claimLiquidity,
    claimLiquidityBatch,
    removeLiquidity,
    removeLiquidityBatch,
    withdrawLiquidity,
    withdrawLiquidityBatch,
    settle
  }
}
