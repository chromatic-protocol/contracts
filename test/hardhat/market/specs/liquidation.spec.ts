import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { parseEther, parseUnits } from 'ethers'
import { helpers, prepareMarketTest } from '../testHelper'

export function spec(getDeps: Function) {
  describe('liquidation test', async () => {
    let testData: Awaited<ReturnType<typeof prepareMarketTest>>
    const eth100 = parseEther('100')

    let cnt = 1

    async function init() {
      testData = await getDeps()
      console.log('='.repeat(50))
      console.log(
        `${cnt++} beforeEach getPositionIds`,
        await testData.traderAccount.getPositionIds(testData.market.getAddress())
      )
      console.log('='.repeat(50))

      const { updatePrice, addLiquidityBatch, claimLiquidityBatch, getLpReceiptIds } =
        helpers(testData)
      await updatePrice(1000)
      // add 10000 usdc liquidity to 0.01% long /short  bin
      // add 50000 usdc liquidity to 0.1% long /short  bin
      await addLiquidityBatch(
        [eth100 * 100n, eth100 * 100n, eth100 * 500n, eth100 * 500n],
        [1n, -1n, 10n, -10n]
      )
      await updatePrice(1000)
      await (await claimLiquidityBatch(await getLpReceiptIds())).wait()
    }

    beforeEach(async () => {
      await init()
    })

    // ETH / USD price feed
    // 186250202000  8 decimal

    async function updatePrice(price: number) {
      await (await testData.oracleProvider.increaseVersion(parseUnits(price.toString(), 8))).wait()
    }

    describe('long position', async () => {
      it('profit stop', async () => {
        // TODO here after lunch

        await updatePrice(2000)
        const takerMargin = parseEther('100') // 100 usd
        // 100
        // 20
        // 120
        const makerMargin = parseEther('190') // 19%
        const openPositionTx = await testData.traderRouter.openPosition(
          testData.market.getAddress(),
          parseEther('1000'), //price precision
          takerMargin, // losscut <= qty
          makerMargin, // profit stop 10 token,
          makerMargin / 100n // maxAllowFee (1% * makerMargin)
        )

        await simulate([2000, 2200, 2400], [1, 1, 0], true)
      })

      it('loss cut', async () => {
        await updatePrice(2000)
        const takerMargin = parseEther('200') // 200 usd 20% loss
        const makerMargin = parseEther('500') // 500 usd
        const openPositionTx = await testData.traderRouter.openPosition(
          testData.market.getAddress(),
          parseEther('1000'), //price precision
          takerMargin, // losscut <= qty
          makerMargin, // profit stop 10 token,
          makerMargin / 100n // maxAllowFee (1% * makerMargin)
        )
        await simulate([2000, 1800, 1600], [1, 1, 0], false)
      })
    })

    describe('short position', async () => {
      it('profit stop', async () => {
        await updatePrice(2000)
        const takerMargin = parseEther('100') // 100 usd
        const makerMargin = parseEther('190') // 19%
        const openPositionTx = await testData.traderRouter.openPosition(
          testData.market.getAddress(),
          -parseEther('1000'), //price precision
          takerMargin, // losscut <= qty
          makerMargin, // profit stop 10 token,
          makerMargin / 100n // maxAllowFee (1% * makerMargin)
        )
        await simulate([2000, 1800, 1600], [1, 1, 0], true)
      })

      it('loss cut', async () => {
        await updatePrice(2000)
        const takerMargin = parseEther('200') // 20%
        const makerMargin = parseEther('120') // 120 usd 20% profit stop
        const openPositionTx = await testData.traderRouter.openPosition(
          testData.market.getAddress(),
          -parseEther('1000'), //price precision
          takerMargin, // losscut <= qty
          makerMargin, // profit stop 10 token,
          makerMargin / 100n // maxAllowFee (1% * makerMargin)
        )

        await simulate([2000, 2200, 2400], [1, 1, 0], false)
      })
    })

    async function simulate(
      priceChanges: number[],
      expectedPreservedPositionLength: number[],
      isProfitStopCase: boolean
    ) {
      const blockStart = await time.latestBlock()

      const { traderAccount, settlementToken } = testData
      const traderBalance = await settlementToken.balanceOf(traderAccount.getAddress())
      console.log(`account balance : ${traderBalance}`)
      await priceChanges.reduce(async (prev, curr, index) => {
        await prev
        await updatePrice(curr)

        // call liquidate (simulate gelato task)
        let positionIds = await testData.traderAccount.getPositionIds(testData.market.getAddress())
        for (const positionId of positionIds) {
          const { canExec } = await testData.liquidator.resolveLiquidation(
            testData.market.getAddress(),
            positionId,
            "0x"
          )
          if (canExec) {
            const marketAddress = testData.market.getAddress()
            const receipt = await testData.liquidator.liquidate(
              testData.market.getAddress(),
              positionId
            )
            expect(receipt)
              .to.emit(traderAccount, 'ClaimPosition')
              .withArgs(marketAddress, positionId, anyValue)
          }
        }

        // check after liquidate
        positionIds = await testData.traderAccount.getPositionIds(testData.market.getAddress())

        const v = await testData.oracleProvider.currentVersion()

        console.log('='.repeat(50))
        console.log('simulate positionIds', positionIds, v.price)
        console.log('='.repeat(50))
        const traderBalance = await settlementToken.balanceOf(traderAccount.getAddress())
        console.log(`oracle price ${curr}, account balance : ${traderBalance}`)
        expect(positionIds.length).to.equal(expectedPreservedPositionLength[index])
      }, Promise.resolve())

      const afterTraderBalance = await settlementToken.balanceOf(traderAccount.getAddress())
      if (isProfitStopCase) {
        expect(traderBalance < afterTraderBalance).to.be.true
      } else {
        console.log('balance', afterTraderBalance, traderBalance)
        expect(afterTraderBalance).to.equal(traderBalance)
      }
    }
  })
}
