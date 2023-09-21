import { time } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { formatEther, parseEther } from 'ethers'
import { helpers, prepareMarketTest } from './testHelper'

interface LiquidityConfig {
  tradingFee: bigint
  amount: bigint
}

  
export function test(prepareMarketFn: Function) {
  describe('interest fee test', async function () {
    let testData: Awaited<ReturnType<typeof prepareMarketTest>>
    const base = parseEther('10')

    beforeEach(async () => {
      testData = await prepareMarketFn()
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
      margin = 10
    }: {
      liquidityConfig: LiquidityConfig[]
      year: bigint
      qty: number
      maxAllowFee?: number
      margin?: number
    }) {
      return async () => {
        await initialize(liquidityConfig)
        let initTimestamp = await time.latest()
        console.log(' first timestamp', initTimestamp)
        console.log('before open position timestamp ', initTimestamp)

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
            parseEther(qty.toString()), //price precision
            takerMargin, // losscut <= qty
            makerMargin, // profit stop token,
            tradingFee // maxAllowFee (0.01% * makerMargin)
          )
        )
        // 1682590676    1682590673
        // 1682590680    1682590676
        await updatePrice(1000)
        const positionIds = await traderAccount.getPositionIds(market.getAddress())
        let wantedTimestamp = BigInt(initTimestamp) + BigInt(60 * 60 * 24 * 365) * year
        await time.setNextBlockTimestamp(wantedTimestamp)
        await awaitTx(traderRouter.closePosition(market.getAddress(), positionIds[0]))
        await updatePrice(1000)
        await awaitTx(traderRouter.claimPosition(market.getAddress(), positionIds[0]))

        console.log('wantedTimestamp ', wantedTimestamp)
        console.log('updated timestamp', initTimestamp)
        console.log('positions', positionIds)
        console.log('position id ', positionIds[0])
        const balanceOfAfterClosePosition = await traderAccount.balance(
          settlementToken.getAddress()
        )

        console.log('after balance ', balanceOfAfterClosePosition)
        const paidFee = balanceBeforePositionPosition - balanceOfAfterClosePosition
        const interestFee = (makerMargin * year) / 10n // 10% annual fee

        const totalFee = tradingFee + interestFee
        console.log(
          `duration ( ${
            ((wantedTimestamp - BigInt(initTimestamp)) * BigInt(24 * 365)) / 3600n
          } year ) paid fee  `,
          formatEther(paidFee)
        )
        expect(paidFee).to.equal(totalFee)
      }
    }

    it(
      '0.01% trading fee & 10% interest Fee / 1 year ',
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
      '0.01% trading fee & 10% interest Fee / 2 year ',
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
      '0.01% trading fee & 10% interest Fee / 3 year ',
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
}
