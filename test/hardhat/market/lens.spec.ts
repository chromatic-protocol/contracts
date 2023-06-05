import { ethers } from 'hardhat'
import { prepareMarketTest, helpers } from './testHelper'
import { BigNumber } from 'ethers'
import { expect } from 'chai'
import { LpReceiptStructOutput } from '@chromatic/typechain-types/contracts/core/ChromaticMarket'

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
    console.log('slotValue', slotValue)
    slotValue.forEach(({ value }, i) => {
      expect(value).to.equal(amounts[i])
    })
  })

  it('get slot liquidity information', async () => {
    const { lens, market } = testData
    const { openPosition } = helpers(testData)

    await openPosition({
      qty: 300 * 10 ** 4,
      leverage: 100,
      takerMargin: ethers.utils.parseEther('300'),
      makerMargin: ethers.utils.parseEther('250'),
      maxAllowFeeRate: 3
    })
    const liquidityInfo = await lens.slotLiquidities(
      market.address,
      feeRates.map((v) => v.toString())
    )

    //TODO test
    console.log('liquidity info', liquidityInfo)

    // total makerMargin : 250
    const tradingFees = [
      ethers.utils.parseEther('1'), // 1% * 100
      ethers.utils.parseEther('2'), // 2% * 100
      ethers.utils.parseEther('1.5') // 3% * 50
    ]

    const exepectedFreeLiquidities = [0, 0, 50]

    liquidityInfo.forEach(({ freeVolume, liquidity }, i) => {
      const expectedFreeLiquidity = ethers.utils
        .parseEther(exepectedFreeLiquidities[i].toString())
        .add(tradingFees[i])
      expect(freeVolume).to.equal(expectedFreeLiquidity)
      expect(liquidity).to.equal(amounts[i].add(tradingFees[i]))
    })
  })

  it('removable liquidity info ', async () => {
    const { lens, market, clbToken,tester,chromaticRouter } = testData
    const { openPosition, removeLiquidity, updatePrice,awaitTx,settle,getLpReceiptIds } = helpers(testData)
    await updatePrice(1000)
    // check user's CLB tokens
    
    // consume all liquidity
    await openPosition({
      qty: 300 * 10 ** 4,
      leverage: 100,
      takerMargin: ethers.utils.parseEther('300'),
      makerMargin: ethers.utils.parseEther('300'),
      maxAllowFeeRate: 3
    })
    console.log('slot values', await lens.slotValue(market.address, feeRates));
    const receipts: LpReceiptStructOutput[] = []
    market.on(market.filters.RemoveLiquidity(), (_, receipt) => {
      console.log('receive receipt event', receipt)
      receipts.push(receipt)
    })
    // Retrieve some liqudity
    console.log('remove liquidity from 100')
    await awaitTx(removeLiquidity(ethers.utils.parseEther('50'), 100))
    
    // next oracle round
    await updatePrice(1000)
    await settle();
    // await awaitTx(removeLiquidity(ethers.utils.parseEther('50'), 100))
    // await updatePrice(1000)
    // await settle();

    // await awaitTx(removeLiquidity(ethers.utils.parseEther('50'), 100))
    // await updatePrice(1000)\=

    await sleep(15000)
    let removableLiquidity = await lens.removableLiquidity(
      market.address,
      receipts.map((r) => r.id)
    )
    receipts.splice(0,receipts.length);

    console.log('removableLiquidity feeRate 100', removableLiquidity)

    // console.log('remove liquidity from 200')
    // await awaitTx(removeLiquidity(ethers.utils.parseEther('50'), 200))
    // await awaitTx(removeLiquidity(ethers.utils.parseEther('50'), 200))
    // await updatePrice(1000)
    // await sleep(5000)
    // removableLiquidity = await lens.removableLiquidity(
    //   market.address,
    //   receipts.map((r) => r.id)
    // )
    // console.log('removableLiquidity feeRate 200', removableLiquidity)
    
  })
})

async function sleep(time: number) {
  return new Promise((resolve) => setTimeout(resolve, time))
}
