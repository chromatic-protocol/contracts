import { ethers } from 'hardhat'
import { prepareMarketTest, helpers } from './testHelper'
import { BigNumber } from 'ethers'
import { expect } from 'chai'
describe('lens', async () => {
  let testData: Awaited<ReturnType<typeof prepareMarketTest>>
  const feeRates = [100, 200, 300]
  const amounts = [
    ethers.utils.parseEther('100'),
    ethers.utils.parseEther('100'),
    ethers.utils.parseEther('100')
  ]
  beforeEach(async () => {
    testData = await prepareMarketTest()
    const {
      claimLiquidity,
      getLpReceiptIds,
      addLiquidity,
      removeLiquidity,
      withdrawLiquidity,
      awaitTx,
      updatePrice,
      addLiquidityBatch,
      claimLiquidityBatch
    } = helpers(testData)
    const { lens, market } = testData

    await updatePrice(1000)
    await awaitTx(addLiquidityBatch(amounts, feeRates))

    await updatePrice(1000)
    await awaitTx(claimLiquidityBatch(await getLpReceiptIds()))
  })

  it('get CBL Value', async () => {
    const { lens, market, trader } = testData
    const { openPosition, updatePrice, closePosition, claimPosition } = helpers(testData)
    let clbValue = await lens.CLBValues(
      market.address,
      feeRates.map((v) => v.toString())
    )

    console.log('clbValue', clbValue)
    await openPosition({
      qty: 300 * 10 ** 4,
      leverage: 100,
      takerMargin: ethers.utils.parseEther('300'),
      makerMargin: ethers.utils.parseEther('300'),
      maxAllowFeeRate: 3
    })

    await updatePrice(1000)
    const openPositionEvent = await market.queryFilter(market.filters.OpenPosition(), 0)

    console.log('open position event', openPositionEvent[0].args[1].id)
    const positionId = openPositionEvent[0].args[1].id
    await closePosition(positionId)
    await updatePrice(500)
    await claimPosition(positionId)
    clbValue = await lens.CLBValues(
      market.address,
      feeRates.map((v) => v.toString())
    )

    console.log('clbValue', clbValue)
    for (let clb of clbValue) {
      expect(clb.value).to.be.not.equal(BigNumber.from(10000))
    }
  })

  it('get Slot Value', async () => {
    const { lens, market } = testData
    const slotValue = await lens.slotValue(
      market.address,
      feeRates.map((v) => v.toString())
    )
    //TODO test
    console.log('slotValue', slotValue)
  })

  it('get slot liquidity information', async () => {
    const { lens, market } = testData
    const { openPosition } = helpers(testData)
    await openPosition()
    const liquidityInfo = await lens.slotLiquidities(
      market.address,
      feeRates.map((v) => v.toString())
    )
    //TODO test
    console.log('liquidity info', liquidityInfo)
  })
})
