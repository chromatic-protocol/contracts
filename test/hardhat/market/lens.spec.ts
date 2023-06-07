import { ethers } from 'hardhat'
import { prepareMarketTest, helpers } from './testHelper'
import { BigNumber } from 'ethers'
import { expect } from 'chai'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import { LpReceiptStructOutput } from '@chromatic/typechain-types/contracts/core/ChromaticMarket'
import util from 'util'
import { PositionStructOutput } from '@chromatic/typechain-types/contracts/core/base/market/Trade'
describe('lens', async () => {
  const initialLiq = ethers.utils.parseEther('100')
  let testData: Awaited<ReturnType<typeof prepareMarketTest>>
  const feeRates = [100, 200, 300]
  const amounts = [initialLiq, initialLiq, initialLiq]
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

    const expectedMargin: any[] = []

    const liquidity100 = liquidityBinFor(initialLiq)(BigNumber.from('100'))
    const liquidity200 = liquidityBinFor(initialLiq)(BigNumber.from('200'))
    const liquidity300 = liquidityBinFor(initialLiq)(BigNumber.from('300'))
    let liquidityOf100 = 100

    let margin100Slot = initialLiq
    for (let i = 0; i < 6; i++) {
      const blockStart = await time.latestBlock()
      console.log('open position block number', blockStart)
      const makerMargin = ethers.utils.parseEther('50')
      await openPosition({
        qty: 50 * 10 ** 4,
        leverage: 100,
        takerMargin: ethers.utils.parseEther('50'),
        makerMargin: makerMargin,
        maxAllowFeeRate: 3
      })
      // positions = await market.getPositions(await traderAccount.getPositionIds(market.address))
      const openPositionEvent = await market.queryFilter(market.filters.OpenPosition(), blockStart)
      console.log('position opened Event ', openPositionEvent.length, openPositionEvent[0].args[1])
      // positions.push(openPositionEvent[0].args[1])
      const margin100 = liquidity100(makerMargin)
      let margin200 = BigNumber.from('0')
      let margin300 = BigNumber.from('0')
      if (margin100.lt(makerMargin)) {
        margin200 = liquidity200(makerMargin.sub(margin100))
      }
      if (margin100.add(margin200).lt(makerMargin) && !margin200.isZero()) {
        margin300 = liquidity300(makerMargin.sub(margin100).sub(margin200))
      }
      expectedMargin.push({
        margin100,
        margin200,
        margin300,
        blockTime: await time.latest(),
        positionId: openPositionEvent[0].args[1].id
      })
    }
    console.log('expected margins ', expectedMargin)
    console.log('Free Liq after open', await lens.liquidityBins(market.address, [100, 200, 300]))

    await updatePrice(1000)
    const positionIds = await traderAccount.getPositionIds(market.address)
    const positions = await market.getPositions(await traderAccount.getPositionIds(market.address))
    
    // const positionIds = positions.map((position) => position.id)
    console.log('positionIds', positionIds)
    console.log(
      'positions',
      util.inspect(
        (await market.getPositions(positionIds)).map((position) => ({
          id: position.id,
          binMargins: position._binMargins
        })),
        { depth: 5 }
      )
    )
    console.log('slot values', await lens.liquidityBinValue(market.address, feeRates))
    const receipts: LpReceiptStructOutput[] = []
    // Retrieve some liqudity
    console.log('remove liquidity from 100')

    const startBlock = await time.latestBlock()
    let currentBlockTime = await time.latest()
    await awaitTx(removeLiquidity(ethers.utils.parseEther('100'), 100))

    // next oracle round
    await updatePrice(1000)
    await settle()

    // await awaitTx(removeLiquidity(ethers.utils.parseEther('50'), 100))
    // await updatePrice(1000)
    // await settle()

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

    console.log((await traderAccount.getPositionIds(market.address)).length)
    const openedPositionCnt = (await traderAccount.getPositionIds(market.address)).length

    console.log('test', ethers.utils.parseEther('100').div(10 ** openedPositionCnt))

    console.log('position ids', positionIds)
    console.log('close position id: ', positionIds[0])
    await awaitTx(closePosition(positionIds[0]))
    await awaitTx(closePosition(positionIds[1]))
    await updatePrice(1000)
    await awaitTx(claimPosition(positionIds[0]))
    await awaitTx(claimPosition(positionIds[1]))
    await settle()

    removableLiquidity = await lens.removableLiquidity(
      market.address,
      receipts.map((r) => r.id)
    )

    // expect increse removable amount
    currentBlockTime = await time.latest()
    console.log(
      'after tranding fee 1% 50 ether position closed (1)',
      formatRemoveLiquidityValue(removableLiquidity)
    )

    const initClbToken = ethers.utils.parseEther('100')
    removableLiquidity.forEach((liquidityInfo) => {
      let totalInterestFee = positions.reduce((acc, position) => {
        const bin = position._binMargins.find(
          (binMargin) => binMargin.tradingFeeRate == liquidityInfo.tradingFeeRate
        )
        return acc.add(
          interestFee(
            bin?.amount || BigNumber.from(0),
            currentBlockTime,
            position.openTimestamp.toNumber(),
            bin?.tradingFeeRate || 0
          )
        )
      }, BigNumber.from(0))

      if (!liquidityInfo.tokenAmount.isZero()) {
        console.log('liquidity info', liquidityInfo)
        console.log(
          'settle / init settle ratio',

          initClbToken.add(totalInterestFee).div(liquidityInfo.tokenAmount),
          ' clb / initclb ratio',
          initClbToken.div(liquidityInfo.clbTokenAmount)
        )
        console.log(' clb / initclb', liquidityInfo.clbTokenAmount, initClbToken)
        console.log(
          ' settle / total Settle / interest ',
          liquidityInfo.tokenAmount,
          initClbToken.add(totalInterestFee),
          totalInterestFee
          // tradingFee
        )
      }
    })
    // 50000003973723997971
    //

    //  50 / 100 =  tokenAmount / initClbToken + margin100.add(interestFee(margin100, currentBlockTime, blockTime, 100))
    // console.log('expected makerMargin with intrest fee ', appliedInterestFeesMargin)
    // console.log('close position id: ', positionIds[1])
    // await awaitTx(closePosition(positionIds[1]))

    // await updatePrice(1000)
    // await awaitTx(claimPosition(positionIds[1]))
    // await settle()

    // // expect increse removable amount
    // console.log('Free Liq after close 1', await lens.liquidityBins(market.address, [100, 200, 300]))
    // removableLiquidity = await lens.removableLiquidity(
    //   market.address,
    //   receipts.map((r) => r.id)
    // )

    // console.log(
    //   'after tranding fee 1% 50 ether position closed (2) ',
    //   formatRemoveLiquidityValue(removableLiquidity)
    // )

    // await awaitTx(closePosition(positionIds[2]))
    // await awaitTx(closePosition(positionIds[3]))
    // await updatePrice(1000)
    // await awaitTx(claimPosition(positionIds[2]))
    // await awaitTx(claimPosition(positionIds[3]))
    // removableLiquidity = await lens.removableLiquidity(
    //   market.address,
    //   receipts.map((r) => r.id)
    // )
    // console.log(
    //   'after tranding fee 2% 100 ether position closed',
    //   formatRemoveLiquidityValue(removableLiquidity)
    // )

    // await awaitTx(closePosition(positionIds[4]))
    // await awaitTx(closePosition(positionIds[5]))
    // await updatePrice(1000)
    // await awaitTx(claimPosition(positionIds[4]))
    // await awaitTx(claimPosition(positionIds[5]))
    // removableLiquidity = await lens.removableLiquidity(
    //   market.address,
    //   receipts.map((r) => r.id)
    // )
    // console.log(
    //   'after tranding fee 3% 100 ether position closed',
    //   formatRemoveLiquidityValue(removableLiquidity)
    // )
  })
})
const liquidityBinFor = (volume: BigNumber) => (feeRate: BigNumber) => (amount: BigNumber) => {
  if (amount.gt(volume)) {
    amount = volume
  }
  volume = volume.sub(amount.mul(BigNumber.from('10000').sub(feeRate)).div(BigNumber.from(10000)))
  return amount
}
function formatRemoveLiquidityValue(removableLiquidities: any) {
  return removableLiquidities?.map((rl: any) => ({
    receiptId: rl.receiptId,
    tradingFeeRate: rl.tradingFeeRate,
    clbTokenAmount: ethers.utils.formatEther(rl.clbTokenAmount),
    burningAmount: ethers.utils.formatEther(rl.burningAmount),
    tokenAmount: ethers.utils.formatEther(rl.tokenAmount)
  }))
}
function interestFee(
  margin: BigNumber,
  currentUnixTime: number,
  positionOpenTime: number,
  bps: number
) {
  const year = BigNumber.from(3600 * 24 * 365)
  return margin
    .mul(BigNumber.from(bps))
    .mul(BigNumber.from(currentUnixTime - positionOpenTime))
    .div(year)
    .div(BigNumber.from(10000))
}
async function sleep(time: number) {
  return new Promise((resolve) => setTimeout(resolve, time))
}
