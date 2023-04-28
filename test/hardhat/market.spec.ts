import {
  OracleProviderMock,
  USUMMarket,
  USUMMarketFactory,
  Token,
  AccountFactory,
  USUMRouter
} from "../../typechain-types"
import { ethers } from "hardhat"
import { expect } from "chai"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
describe("market test", async function () {
  // start anvil & deploy contract
  // current oracle view
  // set oracle price -> return oracle version을 포함한 어떤 정보
  // add/remove liquidity
  // open/close position
  // execute keeper

  async function getDeployedContract<T>(contractName: string) {
    const deployResult = await import(
      `../../deployments/anvil/${contractName}.json`
    )
    return (await ethers.getContractAt(
      contractName,
      deployResult.address,
      owner
    )) as T
  }

  let oracleProvider: OracleProviderMock
  let marketFactory: USUMMarketFactory
  let settlementToken: Token
  let market: USUMMarket
  let accountFactory: AccountFactory
  let usumRouter: USUMRouter
  let owner: SignerWithAddress
  let tester: SignerWithAddress

  before(async () => {
    // await deploy()
    ;[owner, tester] = await ethers.getSigners()
    console.log("owner", owner)
    marketFactory = await getDeployedContract<USUMMarketFactory>(
      "USUMMarketFactory"
    )
    settlementToken = await getDeployedContract<Token>("Token")
    oracleProvider = await getDeployedContract<OracleProviderMock>(
      "OracleProviderMock"
    )
    const marketAddress = await marketFactory.getMarket(
      oracleProvider.address,
      settlementToken.address
    )
    market = await ethers.getContractAt("USUMMarket", marketAddress)

    accountFactory = await getDeployedContract<AccountFactory>("AccountFactory")
    usumRouter = await getDeployedContract<USUMRouter>("USUMRouter")
  })

  it("change oracle price ", async () => {
    const { version, timestamp, price } = await oracleProvider.currentVersion()
    const balance = await owner.getBalance()
    await oracleProvider
      .connect(owner)
      .increaseVersion(ethers.utils.parseEther("100"),{from:owner.address})
    const { version: nextVersion, price: nextPrice } =
      await oracleProvider.currentVersion()
    console.log("prev", version, price)
    console.log("after update", nextVersion, nextPrice)
    expect(nextVersion).to.equal(version.add(1))
    expect(nextPrice).to.equal(ethers.utils.parseEther("100"))
  })

  it("add liquidty", async () => {
    //
  })

  it("remove liquidity", async () => {})
})
