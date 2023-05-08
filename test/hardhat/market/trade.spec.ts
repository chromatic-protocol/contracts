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

describe("position & account test", async function () {
  let testData: Awaited<ReturnType<typeof prepareMarketTest>>
  const base = ethers.utils.parseEther("10")
  async function initialize() {
    testData = await prepareMarketTest()
    const { addLiquidity } = helpers(testData)
    await addLiquidity(base, 1)
    await addLiquidity(base.mul(5), 10)
    await addLiquidity(base, -1)
    await addLiquidity(base.mul(5), -10)
  }

  before(async () => {
    // market deploy
    await initialize()
  })

  it("open long position", async () => {
    const {
      traderAccount,
      market,
      traderRouter,
      oracleProvider,
      settlementToken,
    } = testData
    const { updatePrice } = helpers(testData)
    expect(await traderAccount.getPositionIds(market.address)).to.deep.equal([])

    await updatePrice(1000)
    const takerMargin = ethers.utils.parseEther("10")
    const makerMargin = ethers.utils.parseEther("50")
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
    expect(slot0?.amount).to.equal(base)
    const slot2 = position._slotMargins.find((p) => p.tradingFeeRate === 10)
    expect(slot2?.amount).to.equal(base.mul(4))
    const totalSlotMargin = position._slotMargins.reduce(
      (acc, curr) => acc.add(curr.amount),
      BigNumber.from(0)
    )
    expect(makerMargin).to.equal(totalSlotMargin)
  })

  it("open short position ", async () => {
    const takerMargin = ethers.utils.parseEther("10")
    const makerMargin = ethers.utils.parseEther("50")
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
    expect(slot0?.amount).to.equal(base)
    const slot2 = position._slotMargins.find((p) => p.tradingFeeRate === 10)
    expect(slot2?.amount).to.equal(base.mul(4))
    const totalSlotMargin = position._slotMargins.reduce(
      (acc, curr) => acc.add(curr.amount),
      BigNumber.from(0)
    )
    expect(makerMargin).to.equal(totalSlotMargin)
  })
})


