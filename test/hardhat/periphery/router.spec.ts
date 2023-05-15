import { ethers } from "hardhat"
import { USUMRouter } from "../../../typechain-types"
import { prepareMarketTest } from "../market/testHelper"
import { deployContract } from "../utils"
import { expect } from "chai"

describe("router test", async () => {
  let testData: Awaited<ReturnType<typeof prepareMarketTest>>
  const base = ethers.utils.parseEther("10")
  before(async () => {
    testData = await prepareMarketTest()
  })

  it("deposit", async () => {
    const { settlementToken, usumRouter } = testData

    const signers = await ethers.getSigners()
    const newTrader = signers[3]
    const emptyAccount = await usumRouter.connect(newTrader).getAccount()
    expect(emptyAccount).to.equal(ethers.constants.AddressZero)
    console.log("before deposit account: ", emptyAccount)
    await settlementToken.connect(newTrader).faucet(1000)
    await settlementToken.connect(newTrader).approve(usumRouter.address, 1000)
    await usumRouter.connect(newTrader).deposit(100, settlementToken.address)

    const account = await usumRouter.connect(newTrader).getAccount()
    expect(account).to.be.a.properAddress;
    console.log("account", account)
  })
})
