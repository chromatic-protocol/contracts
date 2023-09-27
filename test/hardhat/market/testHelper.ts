import { CLBToken__factory } from '@chromatic/typechain-types'
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { MaxUint256, parseEther, parseUnits } from 'ethers'
import { ethers } from 'hardhat'
import { deploy as marketDeploy } from '../deployMarket'

export const prepareMarketTest = async (target: string = 'arbitrum') => {
  async function faucet(account: SignerWithAddress) {
    const tokenOwnerAddress = await settlementToken.connect(account).owner()
    // owner is deployer
    // await ethers.provider.send('hardhat_impersonateAccount', [tokenOwnerAddress])
    const tokenOwner = await ethers.getSigner(tokenOwnerAddress)
    const token = settlementToken.connect(tokenOwner)
    const amount = parseEther('1000000000')
    await (await token.faucet(amount)).wait()
    await (await token.transfer(account, amount)).wait()
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
  } = await loadFixture(marketDeploy(target))
  const [owner, tester, trader] = await ethers.getSigners()
  console.log('owner', owner.address)

  const approveTx = await settlementToken
    .connect(tester)
    .approve(await chromaticRouter.getAddress(), MaxUint256)
  await approveTx.wait()

  await faucet(tester)
  await faucet(trader)

  if ((await chromaticRouter.connect(trader).getAccount()) === ethers.ZeroAddress) {
    const createAccountTx = await chromaticRouter.connect(trader).createAccount()
    await createAccountTx.wait()
  }

  const traderAccountAddr = await chromaticRouter.connect(trader).getAccount()
  const traderAccount = await ethers.getContractAt('ChromaticAccount', traderAccountAddr)

  // logYellow(`\ttraderAccount: ${traderAccount}`)

  const transferTx = await settlementToken
    .connect(trader)
    .transfer(traderAccountAddr, parseEther('1000000'))
  await transferTx.wait()

  const traderRouter = chromaticRouter.connect(trader)
  await (
    await settlementToken.connect(trader).approve(await traderRouter.getAddress(), MaxUint256)
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
    qty = parseEther('10'),
    maxAllowFeeRate = 1n
  }: {
    takerMargin?: bigint
    makerMargin?: bigint
    qty?: bigint
    maxAllowFeeRate?: bigint
  } = {}) {
    const openPositionTx = await traderRouter.openPosition(
      market.getAddress(),
      qty,
      takerMargin, // losscut 1 token
      makerMargin, // profit stop 10 token,
      (makerMargin * maxAllowFeeRate) / 100n // maxAllowFee (1% * makerMargin)
    )
    const receipt = await openPositionTx.wait()
    return {
      receipt,
      makerMargin,
      takerMargin,
      qty
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
    console.log('tester : ', tester, 'market address', await market.getAddress())
    return chromaticRouter.connect(tester)['getLpReceiptIds(address)'](await market.getAddress())
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
    return (await market.settleAll()).wait()
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
