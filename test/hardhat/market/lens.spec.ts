import { ethers } from 'hardhat'
import { prepareMarketTest, helpers } from './testHelper'

describe('lens', async () => {
  let testData: Awaited<ReturnType<typeof prepareMarketTest>>
  beforeEach(async () => {
    testData = await prepareMarketTest()
  })

  it('get CBL Value', async () => {
    const {
      claimLiquidity,
      getLpReceiptIds,
      addLiquidity,
      removeLiquidity,
      withdrawLiquidity,
      awaitTx,
      updatePrice
    } = helpers(testData)
    await updatePrice(1000)
    await addLiquidity(ethers.utils.parseEther('100'), 100)
    await updatePrice(1000)
    const receiptIds = await getLpReceiptIds()
    await awaitTx(claimLiquidity(receiptIds[0]))


    
  })

  it('get Slot Value', async () => {})

  it('get slot liquidity information', async () => {})
})
