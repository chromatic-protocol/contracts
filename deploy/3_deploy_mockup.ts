import { USDC_ARBITRUM_GOERLI } from '@uniswap/smart-order-router'
import chalk from 'chalk'
import { BigNumber } from 'ethers'
import { parseUnits } from 'ethers/lib/utils'
import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const deployOpts = { from: deployer }

  const { address: multicall3Address } = await deploy('Multicall3', deployOpts)
  console.log(chalk.yellow(`✨ Multicall3: ${multicall3Address}`))

  const { address: oracleProviderAddress } = await deploy('OracleProviderMock', deployOpts)
  console.log(chalk.yellow(`✨ OracleProviderMock: ${oracleProviderAddress}`))

  const { address: marketFactoryAddress, libraries: marketFactoryLibaries } = await deployments.get(
    'ChromaticMarketFactory'
  )

  const MarketFactory = await ethers.getContractFactory('ChromaticMarketFactory', {
    libraries: marketFactoryLibaries
  })
  const marketFactory = MarketFactory.attach(marketFactoryAddress)

  await marketFactory.registerOracleProvider(
    oracleProviderAddress,
    {
      minStopLossBPS: 1000, // 10%
      maxStopLossBPS: 10000, // 100%
      minTakeProfitBPS: 1000, // 10%
      maxTakeProfitBPS: 100000, // 1000%
      leverageLevel: 0
    },
    deployOpts
  )
  console.log(chalk.yellow('✨ Register OracleProvider'))

  await marketFactory.registerSettlementToken(
    USDC_ARBITRUM_GOERLI.address,
    parseUnits('10', USDC_ARBITRUM_GOERLI.decimals), // minimumMargin
    BigNumber.from('1000'), // interestRate, 10%
    BigNumber.from('500'), // flashLoanFeeRate, 5%
    parseUnits('1000', USDC_ARBITRUM_GOERLI.decimals), // earningDistributionThreshold, $1000
    BigNumber.from('3000'), // uniswapFeeRate, 0.3%
    deployOpts
  )
  console.log(chalk.yellow('✨ Register SettlementToken'))

  await marketFactory.createMarket(oracleProviderAddress, USDC_ARBITRUM_GOERLI.address, deployOpts)
  console.log(chalk.yellow('✨ Create Market'))
  console.log(chalk.yellow('✨ Done!'))
}

export default func

func.id = 'deploy_mockup' // id required to prevent reexecution
func.tags = ['mockup']
