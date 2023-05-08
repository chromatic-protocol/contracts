import { time } from "@nomicfoundation/hardhat-network-helpers"
import { expect } from "chai"
import { BigNumber, ethers } from "ethers"
import { helpers, prepareMarketTest } from "./testHelper"

interface LiquidityConfig {
  tradingFee: number
  amount: BigNumber
}
describe("interest fee test", async function () {
  let testData: Awaited<ReturnType<typeof prepareMarketTest>>
  const base = ethers.utils.parseEther("10")
  async function initialize(liquidityMap: LiquidityConfig[]) {
    testData = await prepareMarketTest()
    const { addLiquidity } = helpers(testData)
    for (const conf of liquidityMap) {
      await addLiquidity(conf.amount, conf.tradingFee)
    }
  }

  function persistPositionFor({
    liquidityConfig,
    year,
    qty,
    leverage = 100,
    margin = 10,
  }: {
    liquidityConfig: LiquidityConfig[]
    year: number
    qty: number
    maxAllowFee?: number
    leverage?: number
    margin?: number
  }) {
    return async () => {
      await initialize(liquidityConfig)
      let timestamp = await time.latest()
      const firstTimestamp = timestamp
      console.log("before open position timestamp ", timestamp)

      let marginEth = ethers.utils.parseEther(margin.toString())
      const takerMargin = marginEth
      const makerMargin = marginEth
      const {
        traderAccount,
        market,
        traderRouter,
        oracleProvider,
        settlementToken,
      } = testData
      const balanceBeforePositionPosition = await traderAccount.balance(
        settlementToken.address
      )

      let direction = qty / Math.abs(qty)
      let availableLiquidity = liquidityConfig
        .filter((l) => (direction > 0 ? l.tradingFee > 0 : l.tradingFee < 0))
        .sort((a, b) => a.tradingFee - b.tradingFee)
      let tradingFee = BigNumber.from("0")
      console.log("availableLiquidity", availableLiquidity)
      for (let liquidity of availableLiquidity) {
        if (marginEth.gt(0)) {
          const holdMargin = marginEth.sub(liquidity.amount).gte(0) ? liquidity.amount : marginEth
          console.log('hold margin', ethers.utils.formatEther(holdMargin))
          tradingFee = tradingFee
            .add(holdMargin.mul(liquidity.tradingFee).div(10000))
          
          marginEth = marginEth.sub(liquidity.amount)
        } else {
          break
        }
      }
      console.log(
        "total expected trading Fee",
        ethers.utils.formatEther(tradingFee)
      )

      console.log(
        "balanceBeforePositionPosition",
        balanceBeforePositionPosition
      )
      const { updatePrice, awaitTx } = helpers(testData)
      await updatePrice(1000)

      // const tradingFee = makerMargin.div(10000)
      const p = await awaitTx(
        traderRouter.openPosition(
          market.address,
          10 ** 4 * qty, //price precision  (4 decimals)
          leverage, // leverage ( x1 )
          takerMargin, // losscut <= qty
          makerMargin, // profit stop token,
          tradingFee, // maxAllowFee (0.01% * makerMargin)
          ethers.constants.MaxUint256
        )
      )
      await updatePrice(1000)
      const positionIds = await traderAccount.getPositionIds(market.address)
      timestamp = await time.latest()
      console.log("after open position timestamp ", timestamp)
      let wantedTimestamp = timestamp + 60 * 60 * 24 * 365 * year
      await time.setNextBlockTimestamp(wantedTimestamp - 1)
      // timestamp = await time.latest()
      console.log("wantedTimestamp ", wantedTimestamp)
      console.log("updated timestamp", timestamp)
      console.log("positions", positionIds)
      console.log("position id ", positionIds[0])
      await awaitTx(
        traderRouter.closePosition(
          market.address,
          positionIds[0],
          ethers.constants.MaxUint256
        )
      )
      const balanceOfAfterClosePosition = await traderAccount.balance(
        settlementToken.address
      )

      console.log("after balance ", balanceOfAfterClosePosition)
      const paidFee = balanceBeforePositionPosition.sub(
        balanceOfAfterClosePosition
      )
      const interestFee = makerMargin.div(10).mul(year) // 10% annual fee

      const totalFee = tradingFee.add(interestFee)
      console.log(
        `duration ( ${
          (wantedTimestamp - firstTimestamp) / 3600 * 24 * 365
        } year ) paid fee  `,
        ethers.utils.formatEther(paidFee)
      )
      expect(ethers.utils.formatEther(paidFee)).to.equal(
        ethers.utils.formatEther(totalFee)
      )
    }
  }

  it(
    "0.01% tradning fee & 10% interest Fee / 1 year ",
    persistPositionFor({
      liquidityConfig: [
        {
          tradingFee: 1,
          amount: ethers.utils.parseEther("50"),
        },
      ],
      year: 1,
      qty: 10,
      margin: 10,
    })
  )

  it(
    "0.01% tradning fee & 10% interest Fee / 2 year ",
    persistPositionFor({
      liquidityConfig: [
        {
          tradingFee: 1,
          amount: ethers.utils.parseEther("50"),
        },
      ],
      year: 1,
      qty: 10,
      margin: 10,
    })
  )
  it(
    "0.01% tradning fee & 10% interest Fee / 3 year ",
    persistPositionFor({
      liquidityConfig: [
        {
          tradingFee: 1,
          amount: ethers.utils.parseEther("50"),
        },
      ],
      year: 1,
      qty: 10,
      margin: 10,
    })
  )

  it(
    "0.01% / 0.02% (10, 40) eth & 10% interest Fee",
    persistPositionFor({
      liquidityConfig: [
        {
          tradingFee: 1,
          amount: ethers.utils.parseEther("10"),
        },
        {
          tradingFee: 3,
          amount: ethers.utils.parseEther("100"),
        },
      ],
      year: 1,
      qty: 50,
      margin: 50,
    })
  )
})
