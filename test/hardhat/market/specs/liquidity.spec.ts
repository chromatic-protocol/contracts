import { CLBToken, IChromaticMarket } from '@chromatic/typechain-types'
import { expect } from 'chai'
import { BigNumberish, parseEther } from 'ethers'
import { logLiquidity } from '../../log-utils'
import { getEventFromTxReceipt } from '../../utils'
import { helpers, prepareMarketTest } from '../testHelper'

export function spec(getDeps: Function) {
  describe('market test', async function () {
    const oneEther = parseEther('1')

    // prettier-ignore
    const fees = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, // 0.01% ~ 0.09%, step 0.01%
    10, 20, 30, 40, 50, 60, 70, 80, 90, // 0.1% ~ 0.9%, step 0.1%
    100, 200, 300, 400, 500, 600, 700, 800, 900, // 1% ~ 9%, step 1%
    1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000 // 10% ~ 50%, step 5%
  ];
    const totalFees = fees
      .map((fee) => -fee)
      .reverse()
      .concat(fees)

    let testData: Awaited<ReturnType<typeof prepareMarketTest>>

    beforeEach(async () => {
      testData = await getDeps()
    })

    it('change oracle price ', async () => {
      const { owner, oracleProvider } = testData
      const { version, price } = await oracleProvider.currentVersion()
      await oracleProvider
        .connect(owner)
        .increaseVersion(parseEther('100'), { from: owner.address })
      const { version: nextVersion, price: nextPrice } = await oracleProvider.currentVersion()
      console.log('prev', version, price)
      console.log('after update', nextVersion, nextPrice)
      expect(nextVersion).to.equal(version + 1n)
      expect(nextPrice).to.equal(parseEther('100'))
    })

    it('add/remove liquidity', async () => {
      const { market, marketEvents, chromaticRouter, tester, clbToken, settlementToken } = testData
      const {
        addLiquidityTx,
        updatePrice,
        claimLiquidity,
        getLpReceiptIds,
        removeLiquidity,
        withdrawLiquidity
      } = helpers(testData)
      await updatePrice(1000)

      const amount = parseEther('100')
      const feeRate = 1

      const expectedLiquidity = await _expectedLiquidity(market, clbToken, feeRate, amount)

      await expect(addLiquidityTx(amount, BigInt(feeRate))).to.changeTokenBalance(
        settlementToken,
        tester.address,
        -amount
      )

      await updatePrice(1100)
      await (await claimLiquidity((await getLpReceiptIds())[0])).wait()

      expect(await clbToken.totalSupply(feeRate)).to.equal(expectedLiquidity)

      const removeLiqAmount = amount / 2n
      const expectedAmount = await _expectedAmount(market, clbToken, feeRate, removeLiqAmount)

      await (await clbToken.setApprovalForAll(chromaticRouter.getAddress(), true)).wait()
      const removeLiqTxReceipt = await (await removeLiquidity(removeLiqAmount, feeRate)).wait()

      const removeLiqReceiptId = getEventFromTxReceipt({
        receipt: removeLiqTxReceipt!,
        eventName: 'RemoveLiquidity',
        iface: marketEvents.interface
      })[0].id

      await updatePrice(1000)

      await expect(withdrawLiquidity(removeLiqReceiptId)).to.changeTokenBalance(
        settlementToken,
        tester,
        expectedAmount
      )

      expect(await clbToken.totalSupply(feeRate)).to.equal(removeLiqAmount)
    })

    it('add/remove liquidity Batch', async () => {
      const { market, chromaticRouter, tester, clbToken, settlementToken, lens } = testData
      const {
        updatePrice,
        addLiquidityBatch,
        claimLiquidityBatch,
        getLpReceiptIds,
        removeLiquidityBatch,
        withdrawLiquidityBatch
      } = helpers(testData)
      await updatePrice(1000)

      const amount = parseEther('100')
      const amounts = totalFees.map((_) => amount)

      const expectedLiquidities = await Promise.all(
        totalFees.map((fee) => _expectedLiquidity(market, clbToken, fee, amount))
      )

      await expect(
        addLiquidityBatch(
          amounts,
          totalFees.map((v) => BigInt(v))
        )
      ).to.changeTokenBalance(settlementToken, tester.address, -amounts.reduce((a, b) => a + b))
      await updatePrice(1100)
      await (await claimLiquidityBatch(await getLpReceiptIds())).wait()

      expect(await clbToken.totalSupplyBatch(totalFees.map((f) => _encodeId(f)))).to.deep.equal(
        expectedLiquidities
      )

      // remove begin
      await (await clbToken.setApprovalForAll(chromaticRouter.getAddress(), true)).wait()

      const expectedAmounts = await Promise.all(
        totalFees.map((fee, i) => _expectedAmount(market, clbToken, fee, expectedLiquidities[i]))
      )
      await (await removeLiquidityBatch(expectedLiquidities, totalFees)).wait()

      await updatePrice(1000)

      await expect(withdrawLiquidityBatch(await getLpReceiptIds())).to.changeTokenBalance(
        settlementToken,
        tester,
        expectedAmounts.reduce((a, b) => a + b)
      )

      expect(
        await await clbToken.totalSupplyBatch(totalFees.map((f) => _encodeId(f)))
      ).to.deep.equal(totalFees.map((_) => 0n))
    })

    it('print liquidity', async () => {
      const { addLiquidityBatch, claimLiquidityBatch, getLpReceiptIds, updatePrice } =
        helpers(testData)

      await updatePrice(1000)

      const amounts = totalFees.map(
        (fee) =>
          oneEther + (oneEther * BigInt(fees.length - fees.indexOf(Math.max(fee, -fee)))) / 20n
      )

      await (
        await addLiquidityBatch(
          amounts,
          totalFees.map((fee) => BigInt(fee))
        )
      ).wait()
      await updatePrice(1200)
      await (await claimLiquidityBatch(await getLpReceiptIds())).wait()

      // const totals: BigNumber[] = [];
      // const unuseds: BigNumber[] = [];
      // for (let i = 0; i < 72; i++) {
      //   totals.push(oneEther.mul(Math.floor((Math.random() + 1) * 99 + 1)));
      //   unuseds.push(totals[i].div(Math.floor(Math.random() * 3 + 1)));
      // }
      // logLiquidity(totals, unuseds);

      const bins = [
        ...(await testData.lens.liquidityBinStatuses(testData.market.getAddress())).slice()
      ].sort((a, b) => Number(a.tradingFeeRate - b.tradingFeeRate))

      const totalMargins = bins.map((b) => b.liquidity)
      const unusedMargins = bins.map((b) => b.freeLiquidity)

      logLiquidity(totalMargins, unusedMargins)
    })

    it('calculate CLBTokenMinting/CLBTokenValue when zero liquidity', async () => {
      const { market, clbToken } = testData
      const { updatePrice } = helpers(testData)
      await updatePrice(1000)

      const amount = parseEther('100')
      const feeRate = 1
      const expectedLiquidity = await _expectedLiquidity(market, clbToken, feeRate, amount)

      expect(expectedLiquidity).to.equal(amount)

      const expectedAmount = await _expectedAmount(market, clbToken, feeRate, amount)
      expect(expectedAmount).to.equal(0)
    })
  })

  const MIN_AMOUNT = 1000n

  async function _expectedLiquidity(
    market: IChromaticMarket,
    clbToken: CLBToken,
    feeRate: number,
    amount: bigint
  ): Promise<bigint> {
    const binValue = (await market.getBinValues([feeRate]))[0]
    const totalSupply = await clbToken.totalSupply(_encodeId(feeRate))
    return totalSupply == 0n
      ? amount
      : (amount * totalSupply) / (binValue < MIN_AMOUNT ? MIN_AMOUNT : binValue)
  }

  async function _expectedAmount(
    market: IChromaticMarket,
    clbToken: CLBToken,
    feeRate: number,
    clbAmount: bigint
  ): Promise<bigint> {
    const binValue = (await market.getBinValues([feeRate]))[0]
    const totalSupply = await clbToken.totalSupply(_encodeId(feeRate))
    return totalSupply == 0n ? 0n : (clbAmount * binValue) / totalSupply
  }

  function _encodeId(feeRate: number): BigNumberish {
    return feeRate > 0 ? feeRate : BigInt(-feeRate) + 10n ** 10n
  }
}
