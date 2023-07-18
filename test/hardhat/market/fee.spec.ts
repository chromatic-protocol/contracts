import { time } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { formatEther, parseEther } from 'ethers'
import { helpers, prepareMarketTest } from './testHelper'

interface LiquidityConfig {
  tradingFee: bigint
  amount: bigint
}
describe('interest fee test', async function () {
  let testData: Awaited<ReturnType<typeof prepareMarketTest>>
  const base = parseEther('10')

  beforeEach(async () => {
    testData = await prepareMarketTest()
  })

  async function initialize(liquidityMap: LiquidityConfig[]) {
    const { addLiquidity, updatePrice, getLpReceiptIds, claimLiquidityBatch } = helpers(testData)
    await updatePrice(1000)
    for (const conf of liquidityMap) {
      await addLiquidity(conf.amount, conf.tradingFee)
    }
    await updatePrice(1000)

    await (await claimLiquidityBatch(await getLpReceiptIds())).wait()
  }

  function persistPositionFor({
    liquidityConfig,
    year,
    qty,
    leverage = 100,
    margin = 10
  }: {
    liquidityConfig: LiquidityConfig[]
    year: bigint
    qty: number
    maxAllowFee?: number
    leverage?: number
    margin?: number
  }) {
    return async () => {
      await initialize(liquidityConfig)
      let timestamp = await time.latest()
      const firstTimestamp = BigInt(timestamp)
      console.log('before open position timestamp ', timestamp)

      let marginEth = parseEther(margin.toString())
      const takerMargin = marginEth
      const makerMargin = marginEth
      const { traderAccount, market, traderRouter, settlementToken } = testData
      const balanceBeforePositionPosition = await traderAccount.balance(
        settlementToken.getAddress()
      )

      let direction = qty / Math.abs(qty)
      let availableLiquidity = liquidityConfig
        .filter((l) => (direction > 0 ? l.tradingFee > 0 : l.tradingFee < 0))
        .sort((a, b) => Number(a.tradingFee - b.tradingFee))
      let tradingFee = 0n
      console.log('availableLiquidity', availableLiquidity)
      for (let liquidity of availableLiquidity) {
        if (marginEth > 0n) {
          const holdMargin = marginEth - liquidity.amount >= 0n ? liquidity.amount : marginEth
          console.log('hold margin', formatEther(holdMargin))
          tradingFee = tradingFee + (holdMargin * liquidity.tradingFee) / 10000n

          marginEth = marginEth - liquidity.amount
        } else {
          break
        }
      }
      console.log('total expected trading Fee', formatEther(tradingFee))

      console.log('balanceBeforePositionPosition', balanceBeforePositionPosition)
      const { updatePrice, awaitTx } = helpers(testData)
      await updatePrice(1000)

      // const tradingFee = makerMargin.div(10000)
      const p = await awaitTx(
        traderRouter.openPosition(
          market.getAddress(),
          10 ** 4 * qty, //price precision  (4 decimals)
          leverage, // leverage ( x1 )
          takerMargin, // losscut <= qty
          makerMargin, // profit stop token,
          tradingFee // maxAllowFee (0.01% * makerMargin)
        )
      )
      await updatePrice(1000)
      const positionIds = await traderAccount.getPositionIds(market.getAddress())

      console.log('after open position timestamp ', timestamp)
      timestamp = await time.latest()
      let wantedTimestamp = BigInt(timestamp) + BigInt(60 * 60 * 24 * 365) * year
      await time.setNextBlockTimestamp(wantedTimestamp - 3n)
      // timestamp = await time.latest()

      await awaitTx(traderRouter.closePosition(market.getAddress(), positionIds[0]))
      await updatePrice(1000)
      await awaitTx(traderRouter.claimPosition(market.getAddress(), positionIds[0]))

      console.log('wantedTimestamp ', wantedTimestamp)
      console.log('updated timestamp', timestamp)
      console.log('positions', positionIds)
      console.log('position id ', positionIds[0])
      const balanceOfAfterClosePosition = await traderAccount.balance(settlementToken.getAddress())

      console.log('after balance ', balanceOfAfterClosePosition)
      const paidFee = balanceBeforePositionPosition - balanceOfAfterClosePosition
      const interestFee = (makerMargin * year) / 10n // 10% annual fee

      const totalFee = tradingFee + interestFee
      console.log(
        `duration ( ${
          ((wantedTimestamp - firstTimestamp) * BigInt(24 * 365)) / 3600n
        } year ) paid fee  `,
        formatEther(paidFee)
      )
      expect(paidFee).to.equal(totalFee)
    }
  }

  it(
    '0.01% tradning fee & 10% interest Fee / 1 year ',
    persistPositionFor({
      liquidityConfig: [
        {
          tradingFee: 1n,
          amount: parseEther('50')
        }
      ],
      year: 1n,
      qty: 10,
      margin: 10
    })
  )

  it(
    '0.01% tradning fee & 10% interest Fee / 2 year ',
    persistPositionFor({
      liquidityConfig: [
        {
          tradingFee: 1n,
          amount: parseEther('50')
        }
      ],
      year: 1n,
      qty: 10,
      margin: 10
    })
  )
  it(
    '0.01% tradning fee & 10% interest Fee / 3 year ',
    persistPositionFor({
      liquidityConfig: [
        {
          tradingFee: 1n,
          amount: parseEther('50')
        }
      ],
      year: 1n,
      qty: 10,
      margin: 10
    })
  )

  it(
    '0.01% / 0.02% (10, 40) eth & 10% interest Fee',
    persistPositionFor({
      liquidityConfig: [
        {
          tradingFee: 1n,
          amount: parseEther('10')
        },
        {
          tradingFee: 3n,
          amount: parseEther('100')
        }
      ],
      year: 1n,
      qty: 50,
      margin: 50
    })
  )
})
