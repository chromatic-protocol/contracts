import { ethers } from 'hardhat'
import { prepareMarketTest, helpers } from './testHelper'
import { BigNumber } from 'ethers'
import { expect } from 'chai'
import { time } from '@nomicfoundation/hardhat-network-helpers'
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
    const claimLiquidityEvent = await market.queryFilter(market.filters.ClaimLiquidity())
    console.log(
      'claim liquidity event',
      claimLiquidityEvent.map((e) => e.args[1])
    )
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
    const slotValue = await lens.liquidityBinValue(
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
    const liquidityInfo = await lens.liquidityBins(
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
    const { lens, market, clbToken, tester, chromaticRouter, traderAccount } = testData
    const {
      openPosition,
      removeLiquidity,
      updatePrice,
      awaitTx,
      settle,
      getLpReceiptIds,
      withdrawLiquidity,
      claimPosition,
      closePosition
    } = helpers(testData)
    await updatePrice(1000)
    // check user's CLB tokens

    console.log('Free Liq before open', await lens.liquidityBins(market.address, [100, 200, 300]))
    // consume all liquidity
    for (let i = 0; i < 6; i++) {
      await openPosition({
        qty: 50 * 10 ** 4,
        leverage: 100,
        takerMargin: ethers.utils.parseEther('50'),
        makerMargin: ethers.utils.parseEther('50'),
        maxAllowFeeRate: 3
      })
    }

    console.log('Free Liq after open', await lens.liquidityBins(market.address, [100, 200, 300]))

    await updatePrice(1000)

    const positionIds = await traderAccount.getPositionIds(market.address)
    console.log('positionIds', positionIds)

    console.log('slot values', await lens.liquidityBinValue(market.address, feeRates))
    const receipts: LpReceiptStructOutput[] = []
    // market.on(market.filters.RemoveLiquidity(), (_, receipt) => {
    //   console.log('receive receipt event', receipt)
    //   receipts.push(receipt)
    // })

    // Retrieve some liqudity
    console.log('remove liquidity from 100')
    const startBlock = await time.latestBlock()
    await awaitTx(removeLiquidity(ethers.utils.parseEther('50'), 100))


    // next oracle round
    await updatePrice(1000)
    await settle()

    await awaitTx(removeLiquidity(ethers.utils.parseEther('50'), 100))
    await updatePrice(1000)
    await settle()

    await awaitTx(removeLiquidity(ethers.utils.parseEther('100'), 200))
    await updatePrice(1000)
    await settle()
    await awaitTx(removeLiquidity(ethers.utils.parseEther('100'), 300))
    await updatePrice(1000)
    await settle()
    // await sleep(20000);
    console.log('block time ', startBlock)
    const removeLiquidityEvent = await market.queryFilter(
      market.filters.RemoveLiquidity(),
      startBlock
    )
    receipts.push(...removeLiquidityEvent.map((e) => e.args[1]))
    console.log('remove liquiditiy receipts', receipts)
    let removableLiquidity = await lens.removableLiquidity(
      market.address,
      receipts.map((r) => r.id)
    )

    console.log('before close position ', formatRemoveLiquidityValue(removableLiquidity))

    // await awaitTx(removeLiquidity(ethers.utils.parseEther('50'), 100))
    // await updatePrice(1000)\=
    console.log('close position id: ', positionIds[0])
    await awaitTx(closePosition(positionIds[0]))
    await updatePrice(1000)
    await awaitTx(claimPosition(positionIds[0]))
    await settle()

    removableLiquidity = await lens.removableLiquidity(
      market.address,
      receipts.map((r) => r.id)
    )

    // expect increse removable amount
    console.log(
      'after tranding fee 1% 50 ether position closed (1)',
      formatRemoveLiquidityValue(removableLiquidity)
    )
    

    console.log('close position id: ', positionIds[1])
    await awaitTx(closePosition(positionIds[1]))

    await updatePrice(1000)
    await awaitTx(claimPosition(positionIds[1]))
    await settle()

    // expect increse removable amount
    console.log('Free Liq after close 1', await lens.liquidityBins(market.address, [100, 200, 300]))
    removableLiquidity = await lens.removableLiquidity(
      market.address,
      receipts.map((r) => r.id)
    )

    console.log(
      'after tranding fee 1% 50 ether position closed (2) ',
      formatRemoveLiquidityValue(removableLiquidity)
    )
    // console.log('ids', await chromaticRouter.connect(tester).getLpReceiptIds(market.address))
    // console.log('clb balance before wl', await clbToken.balanceOf(tester.address,100))

    // await awaitTx(withdrawLiquidity(receipts[0].id))

    // // 49999999990100000298
    // // 0.000000009899999702
    // console.log('clb balance after wl', await clbToken.balanceOf(tester.address,100))

    // const ids = await chromaticRouter.connect(tester).getLpReceiptIds(market.address)
    // console.log('ids', await chromaticRouter.connect(tester).getLpReceiptIds(market.address))
    // removableLiquidity = await lens.removableLiquidity(market.address, ids)

    // console.log(
    //   'after tranding fee 1% 50 ether withdraw',
    //   formatRemoveLiquidityValue(removableLiquidity)
    // )

    // close

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

function formatRemoveLiquidityValue(removableLiquidities: any) {
  return removableLiquidities?.map((rl: any) => ({
    receiptId: rl.receiptId,
    tradingFeeRate: rl.tradingFeeRate,
    clbTokenAmount: ethers.utils.formatEther(rl.clbTokenAmount),
    burningAmount: ethers.utils.formatEther(rl.burningAmount),
    tokenAmount: ethers.utils.formatEther(rl.tokenAmount)
  }))
}
async function sleep(time: number) {
  return new Promise((resolve) => setTimeout(resolve, time))
}
