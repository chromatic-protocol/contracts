import { PositionStructOutput } from '@chromatic/typechain-types/contracts/core/interfaces/IChromaticMarket'
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import bluebird from 'bluebird'
import { expect } from 'chai'
import { Result, formatEther, parseEther, parseUnits } from 'ethers'
import { helpers, prepareMarketTest } from '../testHelper'

export function spec(getDeps: Function) {
  describe('position & account test', async function () {
    let testData: Awaited<ReturnType<typeof prepareMarketTest>>
    const base = parseEther('1000')
    async function initialize() {
      testData = await getDeps()

      const { updatePrice, addLiquidityBatch, claimLiquidityBatch, getLpReceiptIds } =
        helpers(testData)
      await updatePrice(1000)
      await addLiquidityBatch([base, base * 5n, base, base * 5n], [1n, 10n, -1n, -10n])
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
      expect(await traderAccount.getPositionIds(market.getAddress())).to.deep.equal([])

      await updatePrice(1000)
      const takerMargin = parseEther('2000')
      const leverage = 2n // x2
      const makerMargin = takerMargin * leverage
      const { receipt } = await openPosition({
        qty: makerMargin,
        takerMargin,
        makerMargin
      })
      expect(receipt).to.emit(traderAccount, 'OpenPosition').withArgs(
        market.target,
        anyValue,
        anyValue,

        anyValue,
        anyValue,
        anyValue,
        anyValue,
        anyValue
      )

      const positionIds = [...(await traderAccount.getPositionIds(market.getAddress()))]
      console.log(positionIds)

      expect(positionIds.length, 'invalid position length').to.equal(1)
      const position = (await market.getPositions(positionIds))[0]
      const bin0 = position._binMargins.find((p) => p.tradingFeeRate == 1n)
      expect(bin0?.amount, 'not matched bin amount').to.equal(base)
      const bin2 = position._binMargins.find((p) => p.tradingFeeRate === 10n)
      expect(bin2?.amount, 'not matched bin2 amount').to.equal(base * 3n)
      const totalBinMargin = position._binMargins.reduce((acc, curr) => acc + curr.amount, 0n)
      expect(makerMargin, 'not matched marker margin ').to.equal(totalBinMargin)
    })

    it('open short position ', async () => {
      const { traderAccount, market, traderRouter, oracleProvider, settlementToken } = testData
      const { updatePrice, openPosition } = helpers(testData)
      await updatePrice(1000)
      const takerMargin = parseEther('2000')
      const leverage = 2n // x2
      const makerMargin = takerMargin * leverage

      const { receipt } = await openPosition({
        qty: -makerMargin,
        takerMargin,
        makerMargin
      })

      expect(receipt).to.emit(traderAccount, 'OpenPosition').withArgs(market.target, anyValue)

      const positionIds = [...(await traderAccount.getPositionIds(market.getAddress()))]
      console.log(positionIds)

      expect(positionIds.length, 'invalid position length').to.equal(1)
      const position = (await market.getPositions(positionIds))[0]
      const bin0 = position._binMargins.find((p) => p.tradingFeeRate == 1n)
      expect(bin0?.amount, 'not matched bin amount').to.equal(base)
      const bin2 = position._binMargins.find((p) => p.tradingFeeRate === 10n)
      expect(bin2?.amount, 'not matched bin2 amount').to.equal(base * 3n)
      const totalBinMargin = position._binMargins.reduce((acc, curr) => acc + curr.amount, 0n)
      expect(makerMargin, 'not matched marker margin ').to.equal(totalBinMargin)
    })

    function getPnl(lvQty: bigint, entryPrice: bigint, exitPrice: bigint) {
      console.log(
        '[getPnl]',
        `enrtyPrice ${formatEther(entryPrice)} , exitPrice : ${formatEther(exitPrice)}`
      )
      const delta = exitPrice - entryPrice
      return (lvQty * delta) / entryPrice
    }

    it('position info', async () => {
      //

      const {
        traderAccount,
        market,
        traderRouter,
        oracleProvider,
        settlementToken,
        marketFactory
      } = testData

      const { updatePrice, openPosition, awaitTx } = helpers(testData)
      await awaitTx(
        marketFactory.appendInterestRateRecord(
          settlementToken.getAddress(),
          1500,
          (await time.latest()) + 100
        )
      )

      await time.increase(101)
      // prevent IOV
      await updatePrice(1)
      const oraclePrices = [1000, 1100, 1300, 1200]
      await bluebird.each(oraclePrices, async (price) => {
        await openPosition()
        await updatePrice(price)
      })

      const positionIds = [...(await traderAccount.getPositionIds(market.getAddress()))]
      const positions = await market.getPositions(positionIds)
      const settleVersions = positions.map((e) => e.openVersion + 1n)
      const entryVersions = await oracleProvider.atVersions(settleVersions)

      const settlementTokenDecimal = 10n ** (await settlementToken.decimals())

      const results = positions.reduce((acc: any[], curr: PositionStructOutput) => {
        const entryPrice = entryVersions.find((v) => v.version == curr.openVersion + 1n)?.price
        if (!entryPrice) throw new Error('Not found oracle version for entry price')

        const makerMargin = curr._binMargins.map((m) => m.amount).reduce((a, b) => a + b)
        acc.push({
          ...(curr as unknown as Result).toObject(),
          // pnl: getPnl(qty, entryPrice, currentPrice),
          entryPrice: entryPrice,
          makerMargin: makerMargin
        })
        return acc
      }, [])

      // results.map((r) => console.log(`position id: ${r.id} pnl : ${ethers.utils.formatEther(r.pnl)}`))

      // update interest fee to 20%
      await awaitTx(
        marketFactory.appendInterestRateRecord(
          settlementToken.getAddress(),
          2000,
          (await time.latest()) + 3600 * 24 * 36.5 // 36.5 day
        )
      )

      const currentTime = await time.increase(3600 * 24 * 36.5 - 1)

      const yearSecond = 3600 * 24 * 365

      const interestRates = await marketFactory.getInterestRateRecords(settlementToken.getAddress())
      // console.log("fees", interestRates);

      await bluebird.each(results, async (r) => {
        const tx = await traderRouter.closePosition(market.getAddress(), r.id)
        await expect(tx)
          .to.emit(traderAccount, 'ClosePosition')
          .withArgs(market.target, anyValue, anyValue, anyValue)
      })

      await updatePrice(1200)

      await bluebird.each(results, async (r, index) => {
        // console.log("expected interest", interestFee);
        const tx = await traderRouter.claimPosition(market.getAddress(), r.id)
        const txTimestamp = await time.latest()
        const filteredInterestFees = [...interestRates]
          .filter((fee) => fee.beginTimestamp <= BigInt(txTimestamp))
          .sort((a, b) => Number(b.beginTimestamp - a.beginTimestamp))

        let calculatedTime = txTimestamp
        let interestFee = 0n

        // calculate total interestFee
        for (let fee of filteredInterestFees) {
          const period =
            calculatedTime - Math.max(Number(fee.beginTimestamp), Number(r.openTimestamp))
          calculatedTime = Number(fee.beginTimestamp)

          const x = r.makerMargin
          const y = fee.annualRateBPS * BigInt(period)
          const denominator = BigInt(yearSecond * 10000)
          let calculatedInterestFee = (x * y) / denominator

          if (calculatedInterestFee > 0n) {
            calculatedInterestFee = calculatedInterestFee + 1n
          }

          interestFee = interestFee + calculatedInterestFee
          if (fee.beginTimestamp <= r.openTimestamp) break
        }

        /// validate pnl
        const currentVersion = await oracleProvider.currentVersion()
        const currentPrice = currentVersion.price
        const expectedPnl = getPnl(r.qty, r.entryPrice, currentPrice)
        const oraclePriceDiff =
          index != results.length
            ? parseUnits(
                (oraclePrices[oraclePrices.length - 1] - oraclePrices[index]).toString(),
                8
              )
            : currentPrice - BigInt(oraclePrices[index]) //
        expect(expectedPnl, 'wrong pnl').to.equal((r.qty * oraclePriceDiff) / r.entryPrice)
        expect(
          parseFloat(expectedPnl.toString()) / parseFloat(r.qty),
          'wrong pnl percentage'
        ).to.equal(Number(oraclePriceDiff) / Number(r.entryPrice))
        console.log(`pnl ${(parseFloat(expectedPnl.toString()) / parseFloat(r.qty)) * 100}%`)

        await expect(tx, 'not matched actual pnl')
          .to.emit(market, 'ClaimPosition')
          .withArgs(await traderAccount.getAddress(), expectedPnl, interestFee, anyValue)

        await expect(tx)
          .to.emit(traderAccount, 'ClaimPosition')
          .withArgs(market.target, anyValue, anyValue, anyValue, anyValue, anyValue, anyValue)
      })
    })
  })
}
