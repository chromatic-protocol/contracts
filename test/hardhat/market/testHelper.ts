import { CLBToken__factory } from '@chromatic/typechain-types'
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { MaxUint256, parseEther, parseUnits } from 'ethers'
import { ethers } from 'hardhat'
import { deploy as marketDeploy } from '../deployMarket'

export const prepareMarketTest = async () => {
  async function faucet(account: SignerWithAddress) {
    const faucetTx = await settlementToken.connect(account).faucet(parseEther('1000000000'))
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
    lens
  } = await loadFixture(marketDeploy)
  const [owner, tester, trader] = await ethers.getSigners()
  console.log('owner', owner.address)

  const approveTx = await settlementToken
    .connect(tester)
    .approve(chromaticRouter.getAddress(), MaxUint256)
  await approveTx.wait()

  await faucet(tester)
  await faucet(trader)

  const createAccountTx = await chromaticRouter.connect(trader).createAccount()
  await createAccountTx.wait()

  const traderAccountAddr = await chromaticRouter.connect(trader).getAccount()
  const traderAccount = await ethers.getContractAt('ChromaticAccount', traderAccountAddr)

  // logYellow(`\ttraderAccount: ${traderAccount}`)

  const transferTx = await settlementToken
    .connect(trader)
    .transfer(traderAccountAddr, parseEther('1000000'))
  await transferTx.wait()

  const traderRouter = chromaticRouter.connect(trader)
  await (
    await settlementToken.connect(trader).approve(traderRouter.getAddress(), MaxUint256)
  ).wait()

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
    await (await oracleProvider.increaseVersion(parseUnits(price.toString(), 8))).wait()
  }

  async function openPosition({
    takerMargin = parseEther('10'),
    makerMargin = parseEther('50'),
    qty = BigInt(10 * 10 ** 4),
    leverage = 500n, // 5 x
    maxAllowFeeRate = 1n
  }: {
    takerMargin?: bigint
    makerMargin?: bigint
    qty?: bigint
    leverage?: bigint
    maxAllowFeeRate?: bigint
  } = {}) {
    const openPositionTx = await traderRouter.openPosition(
      market.getAddress(),
      qty,
      leverage,
      takerMargin, // losscut 1 token
      makerMargin, // profit stop 10 token,
      (makerMargin * maxAllowFeeRate) / 100n // maxAllowFee (1% * makerMargin)
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

  async function closePosition(positionId: bigint) {
    const closePositionTx = await traderRouter.closePosition(market.getAddress(), positionId)
    const receipt = (await closePositionTx.wait())!

    return {
      receipt,
      blockNumber: closePositionTx.blockNumber,
      blockHash: receipt.blockHash,
      transactionHash: closePositionTx.hash,
      timestamp: (await closePositionTx.getBlock())!.timestamp
    }
  }

  async function getLpReceiptIds() {
    return chromaticRouter.connect(tester)['getLpReceiptIds(address)'](market.getAddress())
  }

  async function addLiquidityTx(amount: bigint, feeBinKey: bigint) {
    return chromaticRouter
      .connect(tester)
      .addLiquidity(market.getAddress(), feeBinKey, amount, tester.address)
  }

  async function addLiquidity(_amount?: bigint, _feeBinKey?: bigint) {
    const amount = _amount ?? parseEther('100')
    const feeBinKey = _feeBinKey ?? 1n

    const addLiqTx = await addLiquidityTx(amount, feeBinKey)
    await addLiqTx.wait()
    return {
      amount,
      feeBinKey
    }
  }

  async function claimPosition(positionId: bigint) {
    const claimTx = await traderRouter.claimPosition(market.getAddress(), positionId)
    return claimTx.wait()
  }

  async function addLiquidityBatch(amounts: bigint[], feeRates: bigint[]) {
    return chromaticRouter
      .connect(tester)
      .addLiquidityBatch(market.getAddress(), tester.address, feeRates, amounts)
  }

  async function claimLiquidity(receiptId: bigint) {
    return chromaticRouter.connect(tester).claimLiquidity(market.getAddress(), receiptId)
  }

  async function claimLiquidityBatch(receiptIds: bigint[]) {
    return chromaticRouter.connect(tester).claimLiquidityBatch(market.getAddress(), [...receiptIds])
  }

  async function removeLiquidity(clbTokenAmount: bigint, feeRate: number) {
    await (
      await testData.clbToken.connect(tester).setApprovalForAll(chromaticRouter.getAddress(), true)
    ).wait()
    return chromaticRouter
      .connect(tester)
      .removeLiquidity(market.getAddress(), feeRate, clbTokenAmount, tester.address)
  }

  async function removeLiquidityBatch(clbTokenAmounts: bigint[], feeRates: number[]) {
    return chromaticRouter
      .connect(tester)
      .removeLiquidityBatch(market.getAddress(), tester.address, feeRates, clbTokenAmounts)
  }

  async function withdrawLiquidity(receiptId: bigint) {
    return chromaticRouter.connect(tester).withdrawLiquidity(market.getAddress(), receiptId)
  }

  async function withdrawLiquidityBatch(receiptIds: bigint[]) {
    return chromaticRouter
      .connect(tester)
      .withdrawLiquidityBatch(market.getAddress(), [...receiptIds])
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
