import { BigNumber } from 'ethers'
import { ethers } from 'hardhat'
import { Keeper } from '../gelato/keeper'
import { prepareMarketTest, helpers } from './testHelper'
import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
describe('liquidation test', async () => {
  let testData: Awaited<ReturnType<typeof prepareMarketTest>>
  const eth100 = ethers.utils.parseEther('100')
  let keeper: Keeper

  let cnt = 1

  async function init() {
    testData = await prepareMarketTest()
    console.log('='.repeat(50))
    console.log(
      `${cnt++} beforeEach getPositionIds`,
      await testData.traderAccount.getPositionIds(testData.market.address)
    )
    console.log('='.repeat(50))

    const { addLiquidity } = helpers(testData)
    // add 10000 usdc liquidity to 0.01% long /short  slot
    await addLiquidity(eth100.mul(100), 1)
    await addLiquidity(eth100.mul(100), -1)

    // add 50000 usdc liquidity to 0.1% long /short  slot
    await addLiquidity(eth100.mul(500), 10)
    await addLiquidity(eth100.mul(500), -10)
    // keeper init
    // 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
    // deployContract<Token>()
    console.log('Automate', testData.gelato.automate.address)
    console.log('Gelato', testData.gelato.gelato.address)
    keeper = new Keeper(
      testData.gelato.automate,
      testData.gelato.gelato,
      BigNumber.from('0'),
      await ethers.getContractAt('ERC20', '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE')
    )
    await keeper.start()
    await new Promise((resolve) => setTimeout(resolve, 1000))
  }
  beforeEach(async () => {
    await init()
  })

  // ETH / USD price feed
  // 186250202000  8 decimal

  async function updatePrice(price: number) {
    await (
      await testData.oracleProvider.increaseVersion(BigNumber.from(price.toString()).mul(10 ** 8))
    ).wait()
  }

  describe('long position', async () => {
    it('profit stop', async () => {
      // TODO here after lunch

      await updatePrice(2000)
      const takerMargin = ethers.utils.parseEther('100') // 100 usd
      // 100
      // 20
      // 120
      const makerMargin = ethers.utils.parseEther('190') // 19%
      const openPositionTx = await testData.traderRouter.openPosition(
        testData.market.address,
        10 ** 4 * 1000, //price precision  (4 decimals)
        100, // leverage ( x1 )
        takerMargin, // losscut <= qty
        makerMargin, // profit stop 10 token,
        makerMargin.mul(1).div(100), // maxAllowFee (1% * makerMargin)
        ethers.constants.MaxUint256
      )

      await simulate([2000, 2200, 2400], [1, 1, 0], true)
    })

    it('loss cut', async () => {
      await updatePrice(2000)
      const takerMargin = ethers.utils.parseEther('200') // 200 usd 20% loss
      const makerMargin = ethers.utils.parseEther('500') // 500 usd
      const openPositionTx = await testData.traderRouter.openPosition(
        testData.market.address,
        10 ** 4 * 1000, //price precision  (4 decimals)
        100, // leverage ( x1 )
        takerMargin, // losscut <= qty
        makerMargin, // profit stop 10 token,
        makerMargin.mul(1).div(100), // maxAllowFee (1% * makerMargin)
        ethers.constants.MaxUint256
      )
      await simulate([2000, 1800, 1600], [1, 1, 0], false)
    })
  })

  describe('short position', async () => {
    it('profit stop', async () => {
      await updatePrice(2000)
      const takerMargin = ethers.utils.parseEther('100') // 100 usd
      const makerMargin = ethers.utils.parseEther('190') // 19%
      const openPositionTx = await testData.traderRouter.openPosition(
        testData.market.address,
        10 ** 4 * 1000 * -1, //price precision  (4 decimals)
        100, // leverage ( x1 )
        takerMargin, // losscut <= qty
        makerMargin, // profit stop 10 token,
        makerMargin.mul(1).div(100), // maxAllowFee (1% * makerMargin)
        ethers.constants.MaxUint256
      )
      await simulate([2000, 1800, 1600], [1, 1, 0], true)
    })

    it('loss cut', async () => {
      await updatePrice(2000)
      const takerMargin = ethers.utils.parseEther('200') // 20%
      const makerMargin = ethers.utils.parseEther('120') // 120 usd 20% profit stop
      const openPositionTx = await testData.traderRouter.openPosition(
        testData.market.address,
        10 ** 4 * 1000 * -1, //price precision  (4 decimals)
        100, // leverage ( x1 )
        takerMargin, // losscut <= qty
        makerMargin, // profit stop 10 token,
        makerMargin.mul(1).div(100), // maxAllowFee (1% * makerMargin)
        ethers.constants.MaxUint256
      )

      await simulate([2000, 2200, 2400], [1, 1, 0], false)
    })
  })

  async function simulate(
    priceChanges: number[],
    expectedPreservedPositionLength: number[],
    isProfitStopCase: boolean
  ) {
    const { traderAccount, settlementToken } = testData
    const traderBalance = await settlementToken.balanceOf(traderAccount.address)
    console.log(`account balance : ${traderBalance}`)
    await priceChanges.reduce(async (prev, curr, index) => {
      await prev
      await updatePrice(curr)
      console.log('keeper tasks', keeper.tasks)
      await keeper.execute()
      let positionIds = await testData.traderAccount.getPositionIds(testData.market.address)

      const v = await testData.oracleProvider.currentVersion()

      console.log('='.repeat(50))
      console.log('simulate positionIds', positionIds, v.price)
      console.log('='.repeat(50))
      const traderBalance = await settlementToken.balanceOf(traderAccount.address)
      console.log(`oracle price ${curr}, account balance : ${traderBalance}`)
      expect(positionIds.length).to.equal(expectedPreservedPositionLength[index])
    }, Promise.resolve())
    const afterTraderBalance = await settlementToken.balanceOf(traderAccount.address)
    if (isProfitStopCase) {
      expect(traderBalance.lt(afterTraderBalance)).to.be.true
    } else {
      console.log('balance', afterTraderBalance, traderBalance)
      expect(afterTraderBalance.eq(traderBalance)).to.be.true
    }
  }
})
