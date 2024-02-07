import { parseEther, parseUnits } from 'ethers'

import { ethers } from 'hardhat'

import { ChromaticLens, ChromaticRouter, TestSettlementToken } from '../../typechain-types'
import { deploy as arbitrumMarketFactoryDeploy } from './market_factory/arbitrum_deploy'
import { deploy as mantleMarketFactoryDeploy } from './market_factory/mantle_deploy'
import { deploy as oracleProviderDeploy } from './oracle_provider/deploy'
import { deployContract, hardhatErrorPrettyPrint } from './utils'

export function deploy(target: string = 'arbitrum') {
  return async function innerDeploy() {
    return hardhatErrorPrettyPrint(async () => {
      console.log('deploy target :', target)
      const marketFactoryDeploy =
        target === 'arbitrum' ? arbitrumMarketFactoryDeploy : mantleMarketFactoryDeploy
      const { marketFactory, keeperFeePayer, liquidator, fixedPriceSwapRouter } =
        await marketFactoryDeploy()
      const oracleProvider = await oracleProviderDeploy()
      const settlementToken = await deployContract<TestSettlementToken>('TestSettlementToken', {
        args: ['Token', 'ST', parseEther('1000'), 86400, 6]
      })
      await fixedPriceSwapRouter.setEthPriceInToken(settlementToken, parseEther('1'))

      const oracleProviderAddress = await oracleProvider.getAddress()
      if (!(await marketFactory.isRegisteredOracleProvider(oracleProviderAddress))) {
        await (
          await marketFactory.registerOracleProvider(oracleProviderAddress, {
            minTakeProfitBPS: 500, // 5%
            maxTakeProfitBPS: 100000, // 1000%
            leverageLevel: 0
          })
        ).wait()
      }

      if (!(await marketFactory.isRegisteredSettlementToken(settlementToken.getAddress()))) {
        await (
          await marketFactory.registerSettlementToken(
            settlementToken.getAddress(),
            oracleProviderAddress,
            10000000n, // minimumMargin
            BigInt('1000'), // interestRate, 10%
            BigInt('500'), // flashLoanFeeRate, 5%
            parseUnits('1000', await settlementToken.decimals()), // earningDistributionThreshold, $1000
            BigInt('3000') // uniswapFeeRate, 0.3%),
          )
        ).wait()
      }

      let marketAddress = await marketFactory.getMarket(
        await oracleProvider.getAddress(),
        await settlementToken.getAddress()
      )
      if (marketAddress === ethers.ZeroAddress) {
        //
        const marketCreateResult = await (
          await marketFactory.createMarket(
            oracleProvider.getAddress(),
            settlementToken.getAddress()
          )
        ).wait()
        const marketCreatedEvents = await marketFactory.queryFilter(
          marketFactory.filters.MarketCreated(),
          (await ethers.provider.getBlockNumber()) - 1000
        )
        marketAddress = marketCreatedEvents[0].args.market
        console.log('market create result ', marketAddress)
      }

      const market = await ethers.getContractAt('IChromaticMarket', marketAddress)
      const marketEvents = await ethers.getContractAt('IMarketEvents', marketAddress)

      const chromaticRouter = await deployContract<ChromaticRouter>('ChromaticRouter', {
        args: [await marketFactory.getAddress()]
      })
      const lens = await deployContract<ChromaticLens>('ChromaticLens', {
        args: [await chromaticRouter.getAddress()]
      })

      return {
        marketFactory,
        keeperFeePayer,
        liquidator,
        oracleProvider,
        market,
        marketEvents,
        chromaticRouter,
        settlementToken,
        lens
      }
    })
  }
}
