import { ChromaticMarketFactory } from '@chromatic/typechain-types'
import chalk from 'chalk'
import { formatUnits, parseUnits } from 'ethers'
import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
import { execute, getGasLimit, getToken } from './utils'

task('settlement-token', 'Show settlement token information')
  .addParam('address', 'The settlement token address or symbol')
  .setAction(
    execute(
      async (
        factory: ChromaticMarketFactory,
        taskArgs: TaskArguments,
        hre: HardhatRuntimeEnvironment
      ): Promise<any> => {
        const token = getToken(taskArgs.address, factory.runner, hre)
        const tokenAddress = await token.getAddress()
        const symbol = await token.symbol()
        const decimals = await token.decimals()
        if (!(await factory.isRegisteredSettlementToken(tokenAddress))) {
          console.log(chalk.red(`'${symbol} (${tokenAddress})' is not registered token`))
          return
        }

        console.log(chalk.green(`Address: ${tokenAddress}`))
        console.log(chalk.green(`Symbol: ${await token.symbol()}`))
        console.log(chalk.green(`Decimals: ${decimals}`))
        console.log(
          chalk.green(
            `MinMargin: ${formatUnits(await factory.getMinimumMargin(tokenAddress), decimals)}`
          )
        )
        console.log(
          chalk.green(
            `InterestRate: ${formatUnits(await factory.currentInterestRate(tokenAddress), 2)}%`
          )
        )
        console.log(
          chalk.green(
            `FlashloanFeeRate: ${formatUnits(await factory.getFlashLoanFeeRate(tokenAddress), 2)}%`
          )
        )
        console.log(
          chalk.green(
            `EarningDistributionThreshold: ${formatUnits(
              await factory.getEarningDistributionThreshold(tokenAddress),
              decimals
            )}`
          )
        )
        console.log(
          chalk.green(
            `UniswapFeeRate: ${formatUnits(await factory.getUniswapFeeTier(tokenAddress), 4)}%`
          )
        )
      }
    )
  )

task('settlement-token:register', 'Register settlement token')
  .addParam('address', 'The settlement token address or symbol')
  .addParam('minMargin', 'The minimum margin for trading', 10, types.float)
  .addParam('interestRate', 'The annual interest rate as a percentage', 10, types.float)
  .addParam('flashloanFeeRate', 'The flashloan fee rate as a percentage', 5, types.float)
  .addParam('earningDistributionThreshold', 'The earning distribution threshold', 1000, types.float)
  .addParam('uniswapFeeRate', 'The uniswap fee rate as a percentage', 0.3, types.float)
  .setAction(
    execute(
      async (
        factory: ChromaticMarketFactory,
        taskArgs: TaskArguments,
        hre: HardhatRuntimeEnvironment
      ): Promise<any> => {
        const token = getToken(taskArgs.address, factory.runner, hre)
        const tokenAddress = await token.getAddress()
        const symbol = await token.symbol()
        if (await factory.isRegisteredSettlementToken(tokenAddress)) {
          console.log(chalk.red(`'${symbol} (${tokenAddress})' is already registered token`))
          return
        }

        const decimals = await token.decimals()
        await (
          await factory.registerSettlementToken(
            tokenAddress,
            parseUnits(taskArgs.minMargin.toString(), decimals),
            parseUnits(taskArgs.interestRate.toString(), 2),
            parseUnits(taskArgs.flashloanFeeRate.toString(), 2),
            parseUnits(taskArgs.earningDistributionThreshold.toString(), decimals),
            parseUnits(taskArgs.uniswapFeeRate.toString(), 4),
            { gasLimit: getGasLimit(hre) }
          )
        ).wait()
        console.log(
          chalk.green(`Success settlement token registration [${symbol}: ${tokenAddress}]`)
        )
      }
    )
  )

task('settlement-token:set', 'Register settlement token')
  .addParam('address', 'The settlement token address or symbol')
  .addOptionalParam('minMargin', 'The minimum margin for trading', undefined, types.int)
  .addOptionalParam(
    'flashloanFeeRate',
    'The flashloan fee rate as a percentage',
    undefined,
    types.float
  )
  .addOptionalParam(
    'earningDistributionThreshold',
    'The earning distribution threshold',
    undefined,
    types.float
  )
  .addOptionalParam(
    'uniswapFeeRate',
    'The uniswap fee rate as a percentage',
    undefined,
    types.float
  )
  .setAction(
    execute(
      async (
        factory: ChromaticMarketFactory,
        taskArgs: TaskArguments,
        hre: HardhatRuntimeEnvironment
      ): Promise<any> => {
        const token = getToken(taskArgs.address, factory.runner, hre)
        const tokenAddress = await token.getAddress()
        const symbol = await token.symbol()
        const decimals = await token.decimals()
        if (!(await factory.isRegisteredSettlementToken(tokenAddress))) {
          console.log(chalk.red(`'${symbol} (${tokenAddress})' is not registered token`))
          return
        }

        if (taskArgs.minMargin) {
          await factory.setMinimumMargin(
            tokenAddress,
            parseUnits(taskArgs.minMargin.toString(), decimals),
            { gasLimit: getGasLimit(hre) }
          )
          console.log(chalk.green('MinMargin is updated'))
        }
        if (taskArgs.flashloanFeeRate) {
          await factory.setFlashLoanFeeRate(
            tokenAddress,
            parseUnits(taskArgs.flashloanFeeRate.toString(), 2),
            { gasLimit: getGasLimit(hre) }
          )
          console.log(chalk.green('FlashloanFeeRate is updated'))
        }
        if (taskArgs.earningDistributionThreshold) {
          await factory.setEarningDistributionThreshold(
            tokenAddress,
            parseUnits(taskArgs.earningDistributionThreshold.toString(), decimals),
            { gasLimit: getGasLimit(hre) }
          )
          console.log(chalk.green('EarningDistributionThreshold is updated'))
        }
        if (taskArgs.uniswapFeeRate) {
          await factory.setUniswapFeeTier(
            tokenAddress,
            parseUnits(taskArgs.uniswapFeeRate.toString(), 4),
            { gasLimit: getGasLimit(hre) }
          )
          console.log(chalk.green('UniswapFeeRate is updated'))
        }
      }
    )
  )
