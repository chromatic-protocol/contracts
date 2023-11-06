import { ChromaticMarketFactory } from '@chromatic/typechain-types'
import chalk from 'chalk'
import { parseEther, parseUnits } from 'ethers'
import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const deployOpts = { from: deployer, gasLimit: '0x1000000' }
  const { address: oracleProviderAddress } = await deploy('OracleProviderMock', deployOpts)
  console.log(chalk.yellow(`✨ OracleProviderMock: ${oracleProviderAddress}`))

  const { address: settlementTokenAddress } = await deploy('TestSettlementToken', {
    args: ['TestSettlementToken', 'cTST', parseEther("100"), 86400],
    ...deployOpts
  })
  console.log(chalk.yellow('✨ Test Settlement Token', settlementTokenAddress))
  const { address: marketFactoryAddress, libraries: marketFactoryLibaries } = await deployments.get(
    'ChromaticMarketFactory'
  )

  const MarketFactory = await ethers.getContractFactory('ChromaticMarketFactory', {
    libraries: marketFactoryLibaries
  })
  const marketFactory = MarketFactory.attach(marketFactoryAddress) as ChromaticMarketFactory

  await (
    await marketFactory.registerOracleProvider(
      oracleProviderAddress,
      {
        minTakeProfitBPS: 1000, // 10%
        maxTakeProfitBPS: 100000, // 1000%
        leverageLevel: 0
      },
      deployOpts
    )
  ).wait()
  console.log(chalk.yellow('✨ Register OracleProvider'))

  // await marketFactory.registerSettlementToken(
  //   USDC_ARBITRUM_GOERLI.address,
  //   parseUnits('10', USDC_ARBITRUM_GOERLI.decimals), // minimumMargin
  //   BigInt('1000'), // interestRate, 10%
  //   BigInt('500'), // flashLoanFeeRate, 5%
  //   parseUnits('1000', USDC_ARBITRUM_GOERLI.decimals), // earningDistributionThreshold, $1000
  //   BigInt('3000'), // uniswapFeeRate, 0.3%
  //   deployOpts
  // )
  // console.log(chalk.yellow('✨ Register SettlementToken'))
  await (
    await marketFactory.registerSettlementToken(
      settlementTokenAddress,
      oracleProviderAddress,
      parseUnits('10', 18), // minimumMargin
      BigInt('1000'), // interestRate, 10%
      BigInt('500'), // flashLoanFeeRate, 5%
      parseUnits('1000', 18), // earningDistributionThreshold, $1000
      BigInt('3000'), // uniswapFeeRate, 0.3%
      deployOpts
    )
  ).wait()

  console.log(chalk.yellow('✨ Register SettlementToken (cTST)'))

  await (
    await marketFactory.createMarket(oracleProviderAddress, settlementTokenAddress, deployOpts)
  ).wait()

  console.log(chalk.yellow('✨ Create Market (cTST)'))
  // await marketFactory.createMarket(oracleProviderAddress, USDC_ARBITRUM_GOERLI.address, deployOpts)
  // console.log(chalk.yellow('✨ Create Market'))
  console.log(chalk.yellow('✨ Done!'))
}

export default func

func.id = 'deploy_mockup' // id required to prevent reexecution
func.tags = ['mockup']
