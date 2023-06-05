import { expect } from 'chai'
import { ethers } from 'hardhat'
import { logLiquidity } from '../log-utils'
import { helpers, prepareMarketTest } from './testHelper'
import { BigNumber } from 'ethers'

describe('market test', async function () {
  const oneEther = ethers.utils.parseEther('1')

  // prettier-ignore
  const fees = [
  1, 2, 3, 4, 5, 6, 7, 8, 9, // 0.01% ~ 0.09%, step 0.01%
  10, 20, 30, 40, 50, 60, 70, 80, 90, // 0.1% ~ 0.9%, step 0.1%
  100, 200, 300, 400, 500, 600, 700, 800, 900, // 1% ~ 9%, step 1%
  1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000 // 10% ~ 50%, step 5%
];
  const totalFees = fees
    .map((fee) => -fee)
    .reverse()
    .concat(fees)

  let testData: Awaited<ReturnType<typeof prepareMarketTest>>

  beforeEach(async () => {
    testData = await prepareMarketTest()
  })

  it('change oracle price ', async () => {
    const { owner, oracleProvider } = testData
    const { version, timestamp, price } = await oracleProvider.currentVersion()
    await oracleProvider
      .connect(owner)
      .increaseVersion(ethers.utils.parseEther('100'), { from: owner.address })
    const { version: nextVersion, price: nextPrice } = await oracleProvider.currentVersion()
    console.log('prev', version, price)
    console.log('after update', nextVersion, nextPrice)
    expect(nextVersion).to.equal(version.add(1))
    expect(nextPrice).to.equal(ethers.utils.parseEther('100'))
  })

  it('add/remove liquidity', async () => {
    const { market, chromaticRouter, tester, clbToken, settlementToken } = testData
    const {
      addLiquidityTx,
      updatePrice,
      claimLiquidity,
      getLpReceiptIds,
      removeLiquidity,
      withdrawLiquidity
    } = helpers(testData)
    await updatePrice(1000)

    const amount = ethers.utils.parseEther('100')
    const feeBinKey = 1

    const expectedLiquidity = await market.calculateCLBTokenMinting(feeBinKey, amount)

    await expect(addLiquidityTx(amount, feeBinKey)).to.changeTokenBalance(
      settlementToken,
      tester.address,
      amount.mul(-1)
    )

    await updatePrice(1100)
    await (await claimLiquidity((await getLpReceiptIds())[0])).wait()

    expect(await clbToken.totalSupply(feeBinKey)).to.equal(expectedLiquidity)

    const removeLiqAmount = amount.div(2)
    const expectedAmount = await market.calculateCLBTokenValue(feeBinKey, removeLiqAmount)

    await (await clbToken.setApprovalForAll(chromaticRouter.address, true)).wait()

    await (await removeLiquidity(removeLiqAmount, feeBinKey)).wait()

    await updatePrice(1000)

    await expect(withdrawLiquidity((await getLpReceiptIds())[0])).to.changeTokenBalance(
      settlementToken,
      tester,
      expectedAmount
    )

    expect(await clbToken.totalSupply(feeBinKey)).to.equal(removeLiqAmount)
  })

  it('add/remove liquidity Batch', async () => {
    const { market, chromaticRouter, tester, clbToken, settlementToken } = testData
    const {
      updatePrice,
      addLiquidityBatch,
      claimLiquidityBatch,
      getLpReceiptIds,
      removeLiquidityBatch,
      withdrawLiquidityBatch
    } = helpers(testData)
    await updatePrice(1000)

    const amount = ethers.utils.parseEther('100')
    const amounts = totalFees.map((_) => amount)

    const expectedLiquidities = await chromaticRouter.calculateCLBTokenMintingBatch(
      market.address,
      totalFees,
      amounts
    )

    await expect(addLiquidityBatch(amounts, totalFees)).to.changeTokenBalance(
      settlementToken,
      tester.address,
      amounts.reduce((a, b) => a.add(b)).mul(-1)
    )
    await updatePrice(1100)
    await (await claimLiquidityBatch(await getLpReceiptIds())).wait()

    expect(await chromaticRouter.totalSupplies(market.address, totalFees)).to.deep.equal(
      expectedLiquidities
    )

    // remove begin
    await (await clbToken.setApprovalForAll(chromaticRouter.address, true)).wait()

    const expectedAmounts = await chromaticRouter.calculateCLBTokenValueBatch(
      market.address,
      totalFees,
      expectedLiquidities
    )

    await (await removeLiquidityBatch(expectedLiquidities, totalFees)).wait()

    await updatePrice(1000)

    await expect(withdrawLiquidityBatch(await getLpReceiptIds())).to.changeTokenBalance(
      settlementToken,
      tester,
      expectedAmounts.reduce((a, b) => a.add(b))
    )

    expect(await chromaticRouter.totalSupplies(market.address, totalFees)).to.deep.equal(
      totalFees.map((_) => BigNumber.from('0'))
    )
  })

  it('print liquidity', async () => {
    const { addLiquidityBatch, claimLiquidityBatch, getLpReceiptIds, updatePrice } =
      helpers(testData)

    await updatePrice(1000)

    const amounts = totalFees.map((fee) =>
      oneEther.add(oneEther.div(20).mul(fees.length - fees.indexOf(Math.max(fee, -fee))))
    )

    await (await addLiquidityBatch(amounts, totalFees)).wait()
    await updatePrice(1200)
    await (await claimLiquidityBatch(await getLpReceiptIds())).wait()

    // const totals: BigNumber[] = [];
    // const unuseds: BigNumber[] = [];
    // for (let i = 0; i < 72; i++) {
    //   totals.push(oneEther.mul(Math.floor((Math.random() + 1) * 99 + 1)));
    //   unuseds.push(totals[i].div(Math.floor(Math.random() * 3 + 1)));
    // }
    // logLiquidity(totals, unuseds);

    const totalMargins = await testData.market.getBinLiquidities(totalFees)
    const unusedMargins = await testData.market.getBinFreeLiquidities(totalFees)

    logLiquidity(totalMargins, unusedMargins)
  })

  it('calculate CLBTokenMinting/CLBTokenValue when zero liquidity', async () => {
    const { market } = testData

    const amount = ethers.utils.parseEther('100')
    const feeBinKey = 1
    const expectedLiquidity = await market.calculateCLBTokenMinting(feeBinKey, amount)
    expect(expectedLiquidity).to.equal(amount)

    const expectedAmount = await market.calculateCLBTokenValue(feeBinKey, amount)
    expect(expectedAmount).to.equal(0)
  })
})
