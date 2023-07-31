import {
  BinMarginStructOutput,
  LpReceiptStructOutput
} from '@chromatic/typechain-types/contracts/core/interfaces/IChromaticMarket'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { Result, formatEther, parseEther } from 'ethers'
import util from 'util'
import { helpers, prepareMarketTest } from './testHelper'

describe('lens', async () => {
  const initialLiq = parseEther('100')
  let testData: Awaited<ReturnType<typeof prepareMarketTest>>
  const feeRates = [100n, 200n, 300n]
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
      qty: parseEther('3000'),
      takerMargin: parseEther('300'),
      makerMargin: parseEther('250'),
      maxAllowFeeRate: 3n
    })
    const liquidityInfo = (await lens.liquidityBinStatuses(market.getAddress())).filter((info) =>
      feeRates.includes(info.tradingFeeRate)
    )

    //TODO test
    console.log('liquidity info', liquidityInfo)

    // total makerMargin : 250
    const tradingFees = [
      parseEther('1'), // 1% * 100
      parseEther('2'), // 2% * 100
      parseEther('1.5') // 3% * 50
    ]
    const exepectedFreeLiquidities = [0, 0, 50]

    liquidityInfo.forEach(({ freeLiquidity, liquidity }, i) => {
      const expectedFreeLiquidity =
        parseEther(exepectedFreeLiquidities[i].toString()) + tradingFees[i]
      expect(freeLiquidity).to.equal(expectedFreeLiquidity)
      expect(liquidity).to.equal(amounts[i] + tradingFees[i])
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

    console.log('Free Liq before open', await lens.liquidityBinStatuses(market.getAddress()))
    // consume all liquidity

    const expectedMargin = []

    const liquidity100 = liquidityBinFor(initialLiq)(100n)
    const liquidity200 = liquidityBinFor(initialLiq)(200n)
    const liquidity300 = liquidityBinFor(initialLiq)(300n)

    //TODO
    for (let i = 0; i < 3; i++) {
      const blockStart = await time.latestBlock()
      console.log('open position block number', blockStart)
      const makerMargin = parseEther('100')
      const takerMargin = makerMargin
      await openPosition({
        qty: parseEther('100'),
        takerMargin,
        makerMargin,
        maxAllowFeeRate: 3n
      })

      const openPositionEvent = await market.queryFilter(market.filters.OpenPosition(), blockStart)
      console.log(
        'position opened Event ',
        openPositionEvent.length,
        openPositionEvent.map((e) => e.args[1])
      )

      const margin100 = liquidity100(makerMargin)
      let margin200 = 0n
      let margin300 = 0n
      if (margin100 < makerMargin) {
        margin200 = liquidity200(makerMargin - margin100)
      }
      if (margin100 + margin200 < makerMargin && margin200 != 0n) {
        margin300 = liquidity300(makerMargin - margin100 - margin200)
      }
      expectedMargin.push({
        margin100,
        margin200,
        margin300,
        blockTime: await time.latest(),
        positionId: openPositionEvent[0].args[1].id
      })
    }

    const totalTradingFee: Record<number, bigint> = {
      100: expectedMargin.reduce((acc, curr) => acc + (curr.margin100 * 100n) / 10000n, 0n),
      200: expectedMargin.reduce((acc, curr) => acc + (curr.margin200 * 200n) / 10000n, 0n),
      300: expectedMargin.reduce((acc, curr) => acc + (curr.margin300 * 300n) / 10000n, 0n)
    }

    console.log('expected margins ', expectedMargin)
    console.log('Free Liq after open')

    await updatePrice(1000)
    const positionIds = [...(await traderAccount.getPositionIds(market.getAddress()))]
    const positions = (await market.getPositions(positionIds)).map((p) =>
      (p as unknown as Result).toObject()
    )

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
      await awaitTx(removeLiquidity(parseEther('100'), 100 * (i + 1)))
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
      positions[i].closeTimestamp = BigInt(closedTime)
    }
    await settle()

    let claimableLiquidities = await Promise.all(
      claimableLiquidityParams.map(async (p) =>
        Object.assign(
          { tradingFeeRate: p.tradingFeeRate },
          (
            (await lens.claimableLiquidity(
              market.getAddress(),
              p.tradingFeeRate,
              p.oracleVersion
            )) as unknown as Result
          ).toObject()
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
    positions[2].closeTimestamp = BigInt(closedTime)
    await settle()

    claimableLiquidities = await Promise.all(
      claimableLiquidityParams.map(async (p) =>
        Object.assign(
          { tradingFeeRate: p.tradingFeeRate },
          (
            (await lens.claimableLiquidity(
              market.getAddress(),
              p.tradingFeeRate,
              p.oracleVersion
            )) as unknown as Result
          ).toObject()
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
        const bin = (position._binMargins as BinMarginStructOutput[]).find(
          (binMargin) => binMargin.tradingFeeRate == liquidityInfo.tradingFeeRate
        )
        return (
          acc +
          interestFee(
            bin?.amount || 0n,
            position.closeTimestamp || BigInt(currentBlockTime),
            position.openTimestamp,
            1000n //
          )
        )
      }, 0n)

      console.log(`total interestFee : ${liquidityBinInterestFee.toString().padEnd(30)}`)
      let tradingFee = totalTradingFee[Number(liquidityInfo.tradingFeeRate)]
      if (liquidityInfo.burningTokenAmount != 0n) {
        const expectedTokenAmount =
          ((initialLiq + liquidityBinInterestFee + tradingFee) *
            liquidityInfo.burningCLBTokenAmount) /
          liquidityInfo.burningCLBTokenAmountRequested

        console.log('liquidity info', liquidityInfo)
        console.log(' real tokenAmount / expected tokenAmount , ratio')

        console.log(
          liquidityInfo.burningTokenAmount.toString().padEnd(30),
          expectedTokenAmount.toString().padEnd(30),
          formatEther(
            (liquidityInfo.burningTokenAmount * parseEther('1')) / expectedTokenAmount
          ).padEnd(30)
        )

        expect(Math.abs(Number(liquidityInfo.burningTokenAmount - expectedTokenAmount)) < 10).to.be
          .true
      }
    }
  })
})

const liquidityBinFor = (volume: bigint) => (feeRate: bigint) => (amount: bigint) => {
  if (amount > volume) {
    amount = volume
  }
  volume = volume - (amount * (10000n - feeRate)) / 10000n
  return amount
}

function formatRemoveLiquidityValue(removableLiquidities: any) {
  return removableLiquidities?.map((rl: any) => ({
    tradingFeeRate: rl.tradingFeeRate,
    burningCLBTokenAmountRequested: rl.burningCLBTokenAmountRequested,
    burningCLBTokenAmount: rl.burningCLBTokenAmount,
    burningTokenAmount: rl.burningTokenAmount,
    formattedBurningCLBTokenAmountRequested: formatEther(rl.burningCLBTokenAmountRequested || 0n),
    formattedBurningCLBTokenAmount: formatEther(rl.burningCLBTokenAmount || 0n),
    formattedBurningTokenAmount: formatEther(rl.burningTokenAmount || 0n)
  }))
}

function interestFee(
  margin: bigint,
  closedOrCurrentTime: bigint,
  positionOpenTime: bigint,
  bps: bigint
) {
  const yearSecond = 3600 * 24 * 365
  const denominator = BigInt(yearSecond * 10000)
  const periodBps = bps * (closedOrCurrentTime - positionOpenTime)
  let interestFee = (margin * periodBps) / denominator
  if (interestFee % denominator > 0n) {
    return interestFee + 1n
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
