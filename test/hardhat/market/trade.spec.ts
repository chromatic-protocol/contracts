import { expect } from "chai"
import { BigNumber } from "ethers"
import { ethers } from "hardhat"
import { helpers, prepareMarketTest } from "./testHelper"
import { time } from "@nomicfoundation/hardhat-network-helpers"
import {
  addYears,
  differenceInYears,
  fromUnixTime,
  getUnixTime,
} from "date-fns"

describe("trade test", async function () {
  let testData: Awaited<ReturnType<typeof prepareMarketTest>>
  const eth10000 = ethers.utils.parseEther("10000")
  before(async () => {
    // market deploy
    testData = await prepareMarketTest()
    const { addLiquidity } = helpers(testData)
    await addLiquidity(eth10000, 1)
    await addLiquidity(eth10000.mul(5), 10)
    await addLiquidity(eth10000, -1)
    await addLiquidity(eth10000.mul(5), -10)
  })

  describe("position & account test", async function () {
    it("open long position", async () => {
      const {
        traderAccount,
        market,
        traderRouter,
        oracleProvider,
        settlementToken,
      } = testData
      const { updatePrice } = helpers(testData)
      expect(await traderAccount.getPositionIds(market.address)).to.deep.equal(
        []
      )

      await updatePrice(1000)
      const takerMargin = ethers.utils.parseEther("100")
      const makerMargin = ethers.utils.parseEther("500")
      const openPositionTx = await traderRouter.openPosition(
        market.address,
        1,
        500,
        takerMargin, // losscut 1 token
        makerMargin, // profit stop 10 token,
        makerMargin.mul(1).div(100), // maxAllowFee (1% * makerMargin)
        ethers.constants.MaxUint256
      )
      const receipt = await openPositionTx.wait()
      console.log(receipt)

      const positionIds = await traderAccount.getPositionIds(market.address)
      console.log(positionIds)

      expect(positionIds.length).to.equal(1)
      const position = await market.getPosition(positionIds[0])

      console.log("position", position)
      console.log("slot0 amount", position._slotMargins[0].amount)
      const slot0 = position._slotMargins.find((p) => p.tradingFeeRate == 1)
      console.log("slot0", slot0)
      expect(slot0?.amount).to.equal(eth10000)
      const slot2 = position._slotMargins.find((p) => p.tradingFeeRate === 10)
      expect(slot2?.amount).to.equal(eth10000.mul(4))
      const totalSlotMargin = position._slotMargins.reduce(
        (acc, curr) => acc.add(curr.amount),
        BigNumber.from(0)
      )
      expect(makerMargin).to.equal(totalSlotMargin)
    })

    it("open short position ", async () => {
      const takerMargin = ethers.utils.parseEther("100")
      const makerMargin = ethers.utils.parseEther("500")
      const {
        traderAccount,
        market,
        traderRouter,
        oracleProvider,
        settlementToken,
      } = testData
      const { updatePrice } = helpers(testData)
      await updatePrice(1000)
      const openPositionTx = await traderRouter.openPosition(
        market.address,
        -1,
        500,
        takerMargin, // losscut 1 token
        makerMargin, // profit stop 10 token,
        makerMargin.mul(1).div(100), // maxAllowFee (1% * makerMargin)
        ethers.constants.MaxUint256
      )
      const receipt = await openPositionTx.wait()
      console.log(receipt)
      //TODO assert result

      const positionIds = await traderAccount.getPositionIds(market.address)
      console.log(positionIds)

      expect(positionIds.length).to.equal(2)
      const position = await market.getPosition(positionIds[1])

      console.log("position", position)
      console.log("slot0 amount", position._slotMargins[0].amount)
      const slot0 = position._slotMargins.find((p) => p.tradingFeeRate === 1)
      console.log("slot0", slot0)
      expect(slot0?.amount).to.equal(eth10000)
      const slot2 = position._slotMargins.find((p) => p.tradingFeeRate === 10)
      expect(slot2?.amount).to.equal(eth10000.mul(4))
      const totalSlotMargin = position._slotMargins.reduce(
        (acc, curr) => acc.add(curr.amount),
        BigNumber.from(0)
      )
      expect(makerMargin).to.equal(totalSlotMargin)
    })
  })

  describe("interest fee test", async function () {
    function persistPositionFor(year: number) {
      return async () => {
        let timestamp = await time.latest()
        const firstTimestamp = timestamp
        console.log("before open position timestamp ", timestamp)

        const takerMargin = ethers.utils.parseEther("1000")
        const makerMargin = ethers.utils.parseEther("1000")
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
        console.log(
          "balanceBeforePositionPosition",
          balanceBeforePositionPosition
        )
        const { updatePrice, awaitTx } = helpers(testData)
        await updatePrice(1000)
        const tradingFee = makerMargin.div(10000)
        const p = await awaitTx(
          traderRouter.openPosition(
            market.address,
            10 ** 4 * 500, //price precision  (4 decimals)
            100, // leverage ( x1 )
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
        // let wantedTimestamp = getUnixTime(
          // addYears(fromUnixTime(timestamp), year)
          
        // )
        await time.setNextBlockTimestamp(wantedTimestamp - 1 )
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
          `duration ( ${(wantedTimestamp - firstTimestamp) / 3600 * 24 * 365 } year ) paid fee  `,
          ethers.utils.formatEther(paidFee)
        )
        expect(ethers.utils.formatEther(paidFee)).to.equal(
          ethers.utils.formatEther(totalFee)
        )
      }
    }
    it("0.01% tradning fee & 10% interest Fee / 1 year ", persistPositionFor(1))
    it("0.01% tradning fee & 10% interest Fee / 2 year ", persistPositionFor(2))
    it("0.01% tradning fee & 10% interest Fee / 3 year ", persistPositionFor(3))
  })
})
