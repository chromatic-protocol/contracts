import { USDC_ARBITRUM_GOERLI } from '@uniswap/smart-order-router'
import { parseUnits } from 'ethers'

import { ethers } from 'hardhat'

import { ChromaticLens, ChromaticRouter, Token } from '../../typechain-types'
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
      const { marketFactory, keeperFeePayer, liquidator } = await marketFactoryDeploy()
      const oracleProvider = await oracleProviderDeploy()
      const settlementToken = await deployContract<Token>('Token', {
        args: ['Token', 'ST']
      })

      const oracleProviderAddress = await oracleProvider.getAddress()
      if (!(await marketFactory.isRegisteredOracleProvider(oracleProviderAddress))) {
        await (
          await marketFactory.registerOracleProvider(
            oracleProviderAddress,
            {
              minTakeProfitBPS: 500, // 5%
              maxTakeProfitBPS: 100000, // 1000%
              leverageLevel: 0
            },
            { gasLimit: 1e6 }
          )
        ).wait()
      }

      if (!(await marketFactory.isRegisteredSettlementToken(settlementToken.getAddress()))) {
        await (
          await marketFactory.registerSettlementToken(
            settlementToken.getAddress(),
            parseUnits('10', USDC_ARBITRUM_GOERLI.decimals), // minimumMargin
            BigInt('1000'), // interestRate, 10%
            BigInt('500'), // flashLoanFeeRate, 5%
            parseUnits('1000', USDC_ARBITRUM_GOERLI.decimals), // earningDistributionThreshold, $1000
            BigInt('3000'), // uniswapFeeRate, 0.3%),
            { gasLimit: 3e7 }
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
            settlementToken.getAddress(),
            { gasLimit: '0x1000000' }
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
        chromaticRouter,
        settlementToken,
        lens
      }
    })
  }
}
