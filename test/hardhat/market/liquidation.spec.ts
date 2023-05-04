import { BigNumber } from "ethers"
import { ethers } from "hardhat"
import { Keeper } from "../gelato/keeper"
import { prepareMarketTest } from "./testHelper"

describe("liquidation test", async () => {
  let testData: Awaited<ReturnType<typeof prepareMarketTest>>
  const eth100 = ethers.utils.parseEther("100")
  let keeper: Keeper

  before(async () => {
    testData = await prepareMarketTest()

    const addLiquidity = testData.addLiquidity
    // add 10000 usdc liquidity to 0.01% long /short  slot 
    await addLiquidity(eth100.mul(100), 1)
    await addLiquidity(eth100.mul(100), -1)

    // add 50000 usdc liquidity to 0.1% long /short  slot 
    await addLiquidity(eth100.mul(500), 10)
    await addLiquidity(eth100.mul(500), -10)
    // keeper init
    // 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
    // deployContract<Token>()
    console.log('Automate',testData.gelato.automate.address)
    console.log('Gelato',testData.gelato.gelato.address)
    keeper = new Keeper(
      testData.gelato.automate,
      testData.gelato.gelato,
      BigNumber.from("0"),
      await ethers.getContractAt(
        "ERC20",
        "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"
      )
    )
    keeper.start()
  })

  // ETH / USD price feed
  // 186250202000  8 decimal

  async function updatePrice(price:number) {
    await (
        await testData.oracleProvider.increaseVersion(
          BigNumber.from(price.toString()).mul(10 ** 8)
        )
      ).wait()
  }

  describe('long position', async()=>{
    it("loss cut", async () => {
        await updatePrice(2000)
        const takerMargin = ethers.utils.parseEther("100") // 100 usd
        const makerMargin = ethers.utils.parseEther("500") // 500 usd
        const openPositionTx = await testData.traderRouter.openPosition(
          testData.oracleProvider.address,
          testData.settlementToken.address,
          10**4 * 500, //price precision  (4 decimals)
          100, // leverage ( x1 )
          takerMargin, // losscut <= qty
          makerMargin, // profit stop 10 token,
          makerMargin.mul(1).div(100), // maxAllowFee (1% * makerMargin)
          ethers.constants.MaxUint256
        )
        console.log('before liquidation position ids', await testData.traderAccount.getPositionIds(testData.market.address));
        // change oracle price
        await updatePrice(2000) // 2000$ / 1ETH settled
        await updatePrice(1599) // 1600$ / 1ETH 20% loss
        // keeper call
        await keeper.execute()

        console.log('after liquidation position ids', await testData.traderAccount.getPositionIds(testData.market.address));

         /// 
    
        
        // ((current - entry) / entry) * qty = pnl
        // (1862/1862 - 1) * 5
    

    
        // check liquidation result
      })
  })
  
  describe('short position', async()=>{
    it('profit stop', async()=>{})
    it('losscut ', async()=>{

    })
  })

  
})
