import { expect } from "chai"
import { ethers } from "hardhat"
import { prepareMarketTest } from "./testHelper"

describe("market test", async function () {
  let testData: Awaited<ReturnType<typeof prepareMarketTest>>

  
  before(async () => {
    testData = await prepareMarketTest()
    
  })

  it("change oracle price ", async () => {
    const { owner, oracleProvider } = testData
    const { version, timestamp, price } = await oracleProvider.currentVersion()
    await oracleProvider
      .connect(owner)
      .increaseVersion(ethers.utils.parseEther("100"), { from: owner.address })
    const { version: nextVersion, price: nextPrice } =
      await oracleProvider.currentVersion()
    console.log("prev", version, price)
    console.log("after update", nextVersion, nextPrice)
    expect(nextVersion).to.equal(version.add(1))
    expect(nextPrice).to.equal(ethers.utils.parseEther("100"))
  })

  it("add/remove liquidity", async () => {
    const {
      market,
      usumRouter,
      tester,
      oracleProvider,
      settlementToken,
      addLiquidity,
    } = testData
    const { amount, feeSlotKey } = await addLiquidity()
    expect(await market.totalSupply(feeSlotKey)).to.equal(amount)

    const removeLiqAmount = amount.div(2)

    await (
      await market.connect(tester).setApprovalForAll(usumRouter.address, true)
    ).wait()

    const removeLiqTx = await usumRouter.connect(tester).removeLiquidity(
      oracleProvider.address,
      settlementToken.address,
      feeSlotKey,
      removeLiqAmount,
      0, // amountMin
      tester.address,
      ethers.constants.MaxUint256 // deadline
    )

    await removeLiqTx.wait()

    expect(await market.totalSupply(feeSlotKey)).to.equal(removeLiqAmount)
  })

})
