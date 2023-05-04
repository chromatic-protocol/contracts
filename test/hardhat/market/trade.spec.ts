import { expect } from "chai"
import { BigNumber, ethers } from "ethers"
import { prepareMarketTest } from "./testHelper"
import { deploy as gelatoDeploy } from "../gelato/deploy"
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers"

describe("position & account test", async () => {
  let testData: Awaited<ReturnType<typeof prepareMarketTest>>
  const eth100 = ethers.utils.parseEther("100")
  before(async () => {
    // market deploy
    testData = await prepareMarketTest()
    const { addLiquidity } = testData
    await addLiquidity(eth100, 1)
    await addLiquidity(eth100.mul(5), 10)
    await addLiquidity(eth100, -1)
    await addLiquidity(eth100.mul(5), -10)
    
  })

  it("open long position", async () => {
    const {
      traderAccount,
      market,
      traderRouter,
      oracleProvider,
      settlementToken,
    } = testData
    expect(await traderAccount.getPositionIds(market.address)).to.deep.equal([])

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
    expect(slot0?.amount).to.equal(eth100)
    const slot2 = position._slotMargins.find((p) => p.tradingFeeRate === 10)
    expect(slot2?.amount).to.equal(eth100.mul(4))
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
    expect(slot0?.amount).to.equal(eth100)
    const slot2 = position._slotMargins.find((p) => p.tradingFeeRate === 10)
    expect(slot2?.amount).to.equal(eth100.mul(4))
    const totalSlotMargin = position._slotMargins.reduce(
      (acc, curr) => acc.add(curr.amount),
      BigNumber.from(0)
    )
    expect(makerMargin).to.equal(totalSlotMargin)
  })
})
