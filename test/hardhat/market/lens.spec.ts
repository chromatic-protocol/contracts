import { LpReceiptStructOutput } from '@chromatic/typechain-types/contracts/core/ChromaticMarket'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { BigNumber } from 'ethers'
import { ethers } from 'hardhat'
import util from 'util'
import { helpers, prepareMarketTest } from './testHelper'
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

  it('get Bin Value', async () => {
    const { lens, market } = testData
    const binValue = await market.getBinValues(feeRates)
    console.log('binValue', binValue)
    binValue.forEach((value, i) => {
      expect(value).to.equal(amounts[i])
    })
  })

  it('get bin liquidity information', async () => {
    const { lens, market } = testData
    const { openPosition } = helpers(testData)

    await openPosition({
      qty: 3000 * 10 ** 4,
      leverage: 10,
      takerMargin: ethers.utils.parseEther('300'),
      makerMargin: ethers.utils.parseEther('250'),
      maxAllowFeeRate: 3
    })
    const liquidityInfo = (await lens.liquidityBinStatuses(market.address)).filter((info) =>
      feeRates.includes(info.tradingFeeRate)
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

    liquidityInfo.forEach(({ freeLiquidity, liquidity }, i) => {
      const expectedFreeLiquidity = ethers.utils
        .parseEther(exepectedFreeLiquidities[i].toString())
        .add(tradingFees[i])
      expect(freeLiquidity).to.equal(expectedFreeLiquidity)
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

    console.log('Free Liq before open', await lens.liquidityBinStatuses(market.address))
    // consume all liquidity

    const expectedMargin = []

    const liquidity100 = liquidityBinFor(initialLiq)(BigNumber.from('100'))
    const liquidity200 = liquidityBinFor(initialLiq)(BigNumber.from('200'))
    const liquidity300 = liquidityBinFor(initialLiq)(BigNumber.from('300'))

    //TODO
    for (let i = 0; i < 3; i++) {
      const blockStart = await time.latestBlock()
      console.log('open position block number', blockStart)
      const makerMargin = ethers.utils.parseEther('100')
      const takerMargin = makerMargin
      await openPosition({
        qty: 100 * 10 ** 4,
        leverage: 100,
        takerMargin,
        makerMargin,
        maxAllowFeeRate: 3
      })

      const openPositionEvent = await market.queryFilter(market.filters.OpenPosition(), blockStart)
      console.log(
        'position opened Event ',
        openPositionEvent.length,
        openPositionEvent.map((e) => e.args[1])
      )

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

    const totalTradingFee: Record<number, BigNumber> = {
      100: expectedMargin.reduce(
        (acc, curr) => acc.add(curr.margin100.mul(100).div(10000)),
        BigNumber.from(0)
      ),
      200: expectedMargin.reduce(
        (acc, curr) => acc.add(curr.margin200.mul(200).div(10000)),
        BigNumber.from(0)
      ),
      300: expectedMargin.reduce(
        (acc, curr) => acc.add(curr.margin300.mul(300).div(10000)),
        BigNumber.from(0)
      )
    }

    console.log('expected margins ', expectedMargin)
    console.log('Free Liq after open')

    await updatePrice(1000)
    const positionIds = await traderAccount.getPositionIds(market.address)
    const positions = [
      ...(await market.getPositions(await traderAccount.getPositionIds(market.address)))
    ]

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
    console.log('bin values', await market.getBinValues(feeRates))
    let receipts: LpReceiptStructOutput[] = []
    // Retrieve some liqudity
    console.log('remove liquidity from 100')

    let eventSubStartBlock = await time.latestBlock()
    for (let i = 0; i < 3; i++) {
      await awaitTx(removeLiquidity(ethers.utils.parseEther('100'), 100 * (i + 1)))
      await updatePrice(1000)
      await settle()
    }

    const removeLiquidityEvent = await market.queryFilter(
      market.filters.RemoveLiquidity(),
      eventSubStartBlock
    )
    receipts = [...removeLiquidityEvent.map((e) => e.args[0])]
    const claimableLiquidityParams = [
      ...new Set(
        receipts.map((r) => ({
          tradingFeeRate: r.tradingFeeRate,
          oracleVersion: r.oracleVersion
        }))
      )
    ]

    await time.increase(3600 * 60 * 365)

    for (let i = 0; i < 2; i++) {
      console.log('close position id : ', positionIds[i])
      await closePosition(positionIds[i])
    }
    await updatePrice(1000)
    for (let i = 0; i < 2; i++) {
      await awaitTx(claimPosition(positionIds[i]))
      const closedTime = await time.latest()
      positions[i] = { ...positions[i], closeTimestamp: BigNumber.from(closedTime) }
    }
    await settle()

    let claimableLiquidities = await Promise.all(
      claimableLiquidityParams.map(async (p) =>
        Object.assign(
          { tradingFeeRate: p.tradingFeeRate },
          await lens.claimableLiquidity(market.address, p.tradingFeeRate, p.oracleVersion)
        )
      )
    )
    console.log('claimable liquidity status (1)', claimableLiquidities)
    await time.increase(3600 * 60 * 365)

    console.log('close position id ', positionIds[2])
    await closePosition(positionIds[2])
    await updatePrice(1000)
    await awaitTx(claimPosition(positionIds[2]))
    const closedTime = await time.latest()
    positions[2] = { ...positions[2], closeTimestamp: BigNumber.from(closedTime) }
    await settle()

    claimableLiquidities = await Promise.all(
      claimableLiquidityParams.map(async (p) =>
        Object.assign(
          { tradingFeeRate: p.tradingFeeRate },
          await lens.claimableLiquidity(market.address, p.tradingFeeRate, p.oracleVersion)
        )
      )
    )
    console.log('claimable liquidity status (2)', claimableLiquidities)
    // expect increse removable amount
    const currentBlockTime = await time.latest()
    console.log(
      'after tranding fee 1% 50 ether position closed (1)',
      formatRemoveLiquidityValue(claimableLiquidities)
    )

    for (let liquidityInfo of claimableLiquidities) {
      console.log('liquidity bin tradingFeeRate:', liquidityInfo.tradingFeeRate)
      let liquidityBinInterestFee = positions.reduce((acc, position) => {
        const bin = position._binMargins.find(
          (binMargin) => binMargin.tradingFeeRate == liquidityInfo.tradingFeeRate
        )
        return acc.add(
          interestFee(
            bin?.amount || BigNumber.from(0),
            position.closeTimestamp?.toNumber() || currentBlockTime,
            position.openTimestamp.toNumber(),
            1000 //
          )
        )
      }, BigNumber.from(0))

      console.log(`total interestFee : ${liquidityBinInterestFee.toString().padEnd(30)}`)
      let tradingFee = totalTradingFee[liquidityInfo.tradingFeeRate]
      if (!liquidityInfo.burningTokenAmount.isZero()) {
        const expectedTokenAmount = initialLiq
          .add(liquidityBinInterestFee)
          .add(tradingFee)
          .mul(liquidityInfo.burningCLBTokenAmount)
          .div(liquidityInfo.burningCLBTokenAmountRequested)

        console.log('liquidity info', liquidityInfo)
        console.log(' real tokenAmount / expected tokenAmount , ratio')

        console.log(
          liquidityInfo.burningTokenAmount.toString().padEnd(30),
          expectedTokenAmount.toString().padEnd(30),
          ethers.utils
            .formatEther(
              liquidityInfo.burningTokenAmount
                .mul(ethers.utils.parseEther('1'))
                .div(expectedTokenAmount)
            )
            .padEnd(30)
        )

        expect(liquidityInfo.burningTokenAmount.sub(expectedTokenAmount).abs().lte(10)).to.be.true
      }
    }
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
    tradingFeeRate: rl.tradingFeeRate,
    burningCLBTokenAmountRequested: rl.burningCLBTokenAmountRequested,
    burningCLBTokenAmount: rl.burningCLBTokenAmount,
    burningTokenAmount: rl.burningTokenAmount,
    formattedBurningCLBTokenAmountRequested: ethers.utils.formatEther(
      rl.burningCLBTokenAmountRequested
    ),
    formattedBurningCLBTokenAmount: ethers.utils.formatEther(rl.burningCLBTokenAmount),
    formattedBurningTokenAmount: ethers.utils.formatEther(rl.burningTokenAmount)
  }))
}

function interestFee(
  margin: BigNumber,
  closedOrCurrentTime: number,
  positionOpenTime: number,
  bps: number
) {
  const yearSecond = 3600 * 24 * 365
  const denominator = BigNumber.from(yearSecond * 10000)
  const periodBps = BigNumber.from(bps * (closedOrCurrentTime - positionOpenTime))
  let interestFee = margin.mul(periodBps).div(denominator)
  if (interestFee.mod(denominator).gt(0)) {
    return interestFee.add(1)
  }
  console.log(
    `margin : ${margin.toString().padEnd(30)}, bps:${bps
      .toString()
      .padEnd(8)} interestFee ${interestFee.toString().padEnd(30)}, from : ${positionOpenTime
      .toString()
      .padEnd(10)} , to: ${closedOrCurrentTime.toString().padEnd(10)}`
  )
  return interestFee
}
