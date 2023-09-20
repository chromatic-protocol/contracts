import { USDC_ARBITRUM_GOERLI } from '@uniswap/smart-order-router'
import { parseUnits } from 'ethers'

import { ethers, network } from 'hardhat'

import { ChromaticLens, ChromaticRouter, Token } from '../../typechain-types'
import { deploy as arbitrumMarketFactoryDeploy } from './market_factory/arbitrum_deploy'
import { deploy as mantleMarketFactoryDeploy } from './market_factory/mantle_deploy'
import { deploy as oracleProviderDeploy } from './oracle_provider/deploy'
import { deployContract, hardhatErrorPrettyPrint } from './utils'
import { HardhatNetworkConfig, NetworkConfig } from 'hardhat/types'

function getForkingChain(forkingOption: HardhatNetworkConfig['forking']) {
  const arbitrumRpcUrls = ['https://arb-goerli.g.alchemy.com/']
  const mantleRpcUrls = ['https://rpc.testnet.mantle.xyz/', 'https://rpc.ankr.com/mantle_testnet']

  for (let url of arbitrumRpcUrls) {
    if (forkingOption?.url.includes(url)) {
      console.log('forking url', url)
      return 'arbitrum'
    }
  }
  for (let url of mantleRpcUrls) {
    if (forkingOption?.url.includes(url)) {
      console.log('forking url', url)
      return 'mantle'
    }
  }
}

export async function deploy() {
  return hardhatErrorPrettyPrint(async () => {
    const networkConfig: HardhatNetworkConfig = network.config as HardhatNetworkConfig
    const marketFactoryDeploy =
      getForkingChain(networkConfig.forking) === 'arbitrum'
        ? arbitrumMarketFactoryDeploy
        : mantleMarketFactoryDeploy
    const { marketFactory, keeperFeePayer, liquidator } = await marketFactoryDeploy()
    const oracleProvider = await oracleProviderDeploy()
    const settlementToken = await deployContract<Token>('Token', {
      args: ['Token', 'ST']
    })

    await (
      await marketFactory.registerOracleProvider(oracleProvider.getAddress(), {
        minTakeProfitBPS: 500, // 5%
        maxTakeProfitBPS: 100000, // 1000%
        leverageLevel: 0
      })
    ).wait()

    await (
      await marketFactory.registerSettlementToken(
        settlementToken.getAddress(),
        parseUnits('10', USDC_ARBITRUM_GOERLI.decimals), // minimumMargin
        BigInt('1000'), // interestRate, 10%
        BigInt('500'), // flashLoanFeeRate, 5%
        parseUnits('1000', USDC_ARBITRUM_GOERLI.decimals), // earningDistributionThreshold, $1000
        BigInt('3000') // uniswapFeeRate, 0.3%)
      )
    ).wait()

    const marketCreateResult = await (
      await marketFactory.createMarket(oracleProvider.getAddress(), settlementToken.getAddress())
    ).wait()
    const marketCreatedEvents = await marketFactory.queryFilter(
      marketFactory.filters.MarketCreated()
    )
    const marketAddress = marketCreatedEvents[0].args.market
    console.log('market create result ', marketAddress)

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
