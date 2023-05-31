import { expect } from 'chai'
import { BigNumber } from 'ethers'
import { ethers } from 'hardhat'
import { helpers, prepareMarketTest } from './testHelper'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import { addYears, differenceInYears, fromUnixTime, getUnixTime } from 'date-fns'
import { PositionStructOutput } from '@usum/typechain-types/contracts/core/USUMMarket'
import { inspect } from 'util'
import bluebird from 'bluebird'
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs'

describe('position & account test', async function () {
  let testData: Awaited<ReturnType<typeof prepareMarketTest>>
  const base = ethers.utils.parseEther('1000')
  async function initialize() {
    testData = await prepareMarketTest()

    const { updatePrice, addLiquidityBatch, claimLiquidityBatch, getLpReceiptIds } =
      helpers(testData)
    await updatePrice(1000)
    await addLiquidityBatch([base, base.mul(5), base, base.mul(5)], [1, 10, -1, -10])
    await updatePrice(1000)
    await (await claimLiquidityBatch(await getLpReceiptIds())).wait()
  }

  beforeEach(async () => {
    // market deploy
    await initialize()
  })

  it('open long position', async () => {
    const { traderAccount, market, traderRouter, oracleProvider, settlementToken } = testData
    const { updatePrice, openPosition } = helpers(testData)
    expect(await traderAccount.getPositionIds(market.address)).to.deep.equal([])

    await updatePrice(1000)
    const takerMargin = ethers.utils.parseEther('2000')
    const leverage = 200
    const makerMargin = takerMargin.mul(leverage / 100)
    const { receipt } = await openPosition({
      qty: 10 ** 4 * Number(ethers.utils.formatEther(base)),
      leverage,
      takerMargin,
      makerMargin
    })

    const positionIds = await traderAccount.getPositionIds(market.address)
    console.log(positionIds)

    expect(positionIds.length, 'invalid position length').to.equal(1)
    const position = (await market.getPositions(positionIds))[0]
    const slot0 = position._slotMargins.find((p) => p.tradingFeeRate == 1)
    expect(slot0?.amount, 'not matched slot amount').to.equal(base)
    const slot2 = position._slotMargins.find((p) => p.tradingFeeRate === 10)
    expect(slot2?.amount, 'not matched slot2 amount').to.equal(base.mul(3))
    const totalSlotMargin = position._slotMargins.reduce(
      (acc, curr) => acc.add(curr.amount),
      BigNumber.from(0)
    )
    expect(makerMargin, 'not matched marker margin ').to.equal(totalSlotMargin)
  })

  it('open short position ', async () => {
    const { traderAccount, market, traderRouter, oracleProvider, settlementToken } = testData
    const { updatePrice, openPosition } = helpers(testData)
    await updatePrice(1000)
    const takerMargin = ethers.utils.parseEther('2000')
    const leverage = 200
    const makerMargin = takerMargin.mul(leverage / 100)

    const { receipt } = await openPosition({
      qty: -(10 ** 4) * Number(ethers.utils.formatEther(base)),
      leverage,
      takerMargin,
      makerMargin
    })

    //TODO assert result

    const positionIds = await traderAccount.getPositionIds(market.address)
    console.log(positionIds)

    expect(positionIds.length, 'invalid position length').to.equal(1)
    const position = (await market.getPositions(positionIds))[0]
    const slot0 = position._slotMargins.find((p) => p.tradingFeeRate == 1)
    expect(slot0?.amount, 'not matched slot amount').to.equal(base)
    const slot2 = position._slotMargins.find((p) => p.tradingFeeRate === 10)
    expect(slot2?.amount, 'not matched slot2 amount').to.equal(base.mul(3))
    const totalSlotMargin = position._slotMargins.reduce(
      (acc, curr) => acc.add(curr.amount),
      BigNumber.from(0)
    )
    expect(makerMargin, 'not matched marker margin ').to.equal(totalSlotMargin)
  })

  function getPnl(lvQty: BigNumber, entryPrice: BigNumber, exitPrice: BigNumber) {
    console.log(
      '[getPnl]',
      `enrtyPrice ${ethers.utils.formatEther(entryPrice)} , exitPrice : ${ethers.utils.formatEther(
        exitPrice
      )}`
    )
    const delta = exitPrice.sub(entryPrice)
    return lvQty.mul(delta).div(entryPrice)
  }

  it('position info', async () => {
    //

    const { traderAccount, market, traderRouter, oracleProvider, settlementToken, marketFactory } =
      testData

    const { updatePrice, openPosition, awaitTx } = helpers(testData)
    await awaitTx(
      marketFactory.appendInterestRateRecord(
        settlementToken.address,
        1500,
        (await time.latest()) + 100
      )
    )

    await time.increase(101)
    // prevent IOV
    await updatePrice(0)
    const oraclePrices = [1000, 1100, 1300, 1200]
    await bluebird.each(oraclePrices, async (price) => {
      await openPosition()
      await updatePrice(price)
    })

    const positionIds = await traderAccount.getPositionIds(market.address)
    const positions = await market.getPositions(positionIds)
    const settleVersions = positions.map((e) => e.openVersion.add(1))
    const entryVersions = await oracleProvider.atVersions(settleVersions)

    const settlementTokenDecimal = BigNumber.from(10).pow(await settlementToken.decimals())
    const QTY_LEVERAGE_PRECISION = BigNumber.from(10).pow(6)

    const results = positions.reduce((acc: any[], curr: PositionStructOutput) => {
      const entryPrice = entryVersions.find((v) => v.version.eq(curr.openVersion.add(1)))?.price
      if (!entryPrice) throw new Error('Not found oracle version for entry price')

      const leveraged = curr.qty
        .abs()
        .mul(settlementTokenDecimal.mul(curr.leverage))
        .div(QTY_LEVERAGE_PRECISION)
      const leveragedQty = curr.qty.lt(0) ? leveraged.mul(-1) : leveraged
      const makerMargin = curr._slotMargins.map((m) => m.amount).reduce((a, b) => a.add(b))
      acc.push({
        ...curr,
        // pnl: getPnl(leveragedQty, entryPrice, currentPrice),
        leveragedQty: leveragedQty,
        entryPrice: entryPrice,
        makerMargin: makerMargin
      })
      return acc
    }, [])

    // results.map((r) => console.log(`position id: ${r.id} pnl : ${ethers.utils.formatEther(r.pnl)}`))

    // update interest fee to 20%
    await awaitTx(
      marketFactory.appendInterestRateRecord(
        settlementToken.address,
        2000,
        (await time.latest()) + 3600 * 24 * 36.5 // 36.5 day
      )
    )

    const currentTime = await time.increase(3600 * 24 * 36.5 - 1)

    const yearSecond = 3600 * 24 * 365

    const interestRates = await marketFactory.getInterestRateRecords(settlementToken.address)
    // console.log("fees", interestRates);

    await bluebird.each(results, async (r) => traderRouter.closePosition(market.address, r.id))

    await updatePrice(1200)

    await bluebird.each(results, async (r, index) => {
      // console.log("expected interest", interestFee);
      const tx = await traderRouter.claimPosition(market.address, r.id)
      const txTimestamp = await time.latest()
      const filteredInterestFees = interestRates
        .filter((fee) => fee.beginTimestamp.lte(BigNumber.from(txTimestamp)))
        .sort((a, b) => b.beginTimestamp.sub(a.beginTimestamp).toNumber())

      let calculatedTime = txTimestamp
      let interestFee = BigNumber.from(0)

      // calculate total interestFee
      for (let fee of filteredInterestFees) {
        const period = calculatedTime - Math.max(fee.beginTimestamp.toNumber(), r.openTimestamp)
        calculatedTime = fee.beginTimestamp.toNumber()

        const x = r.makerMargin
        const y = fee.annualRateBPS.mul(period)
        const denominator = BigNumber.from(yearSecond * 10000)
        let calculatedInterestFee = x.mul(y).div(denominator)
        // mulDiv Round.Up
        // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol#LL139C1-L139C1
        if (x.mul(y).mod(denominator).gt(0)) {
          calculatedInterestFee = calculatedInterestFee.add(1)
        }

        interestFee = interestFee.add(calculatedInterestFee)
        if (fee.beginTimestamp.lte(r.openTimestamp)) break
      }

      /// validate pnl
      const currentVersion = await oracleProvider.currentVersion()
      const currentPrice = currentVersion.price
      const expectedPnl = getPnl(r.leveragedQty, r.entryPrice, currentPrice)
      const oraclePriceDiff =
        index != results.length
          ? BigNumber.from(oraclePrices[oraclePrices.length - 1] - oraclePrices[index]).mul(10 ** 8)
          : currentPrice.sub(oraclePrices[index]) //
      expect(expectedPnl, 'wrong pnl').to.equal(
        r.leveragedQty.mul(oraclePriceDiff).div(r.entryPrice)
      )
      expect(
        parseFloat(expectedPnl.toString()) / parseFloat(r.leveragedQty),
        'wrong pnl percentage'
      ).to.equal(oraclePriceDiff.toNumber() / r.entryPrice.toNumber())
      console.log(`pnl ${(parseFloat(expectedPnl.toString()) / parseFloat(r.leveragedQty)) * 100}%`)

      await expect(tx, 'not matched actual pnl')
        .to.emit(market, 'ClaimPosition')
        .withArgs(traderAccount.address, expectedPnl, interestFee, anyValue)
    })
  })
})
