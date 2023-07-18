import { ChromaticMarketFactory } from '@chromatic/typechain-types'
import chalk from 'chalk'
import { formatUnits, parseUnits } from 'ethers'
import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
import { execute, getToken } from './utils'

task('settlement-token', 'Show settlement token information')
  .addParam('address', 'The settlement token address or symbol')
  .setAction(
    execute(
      async (
        factory: ChromaticMarketFactory,
        taskArgs: TaskArguments,
        hre: HardhatRuntimeEnvironment
      ): Promise<any> => {
        const token = getToken(taskArgs.address, factory.signer, hre)
        const symbol = await token.symbol()
        const decimals = await token.decimals()
        if (!(await factory.isRegisteredSettlementToken(token.address))) {
          console.log(chalk.red(`'${symbol} (${token.address})' is not registered token`))
          return
        }

        console.log(chalk.green(`Address: ${token.address}`))
        console.log(chalk.green(`Symbol: ${await token.symbol()}`))
        console.log(chalk.green(`Decimals: ${decimals}`))
        console.log(
          chalk.green(
            `MinMargin: ${formatUnits(await factory.getMinimumMargin(token.address), decimals)}`
          )
        )
        console.log(
          chalk.green(
            `InterestRate: ${formatUnits(await factory.currentInterestRate(token.address), 2)}%`
          )
        )
        console.log(
          chalk.green(
            `FlashloanFeeRate: ${formatUnits(await factory.getFlashLoanFeeRate(token.address), 2)}%`
          )
        )
        console.log(
          chalk.green(
            `EarningDistributionThreshold: ${formatUnits(
              await factory.getEarningDistributionThreshold(token.address),
              decimals
            )}`
          )
        )
        console.log(
          chalk.green(
            `UniswapFeeRate: ${formatUnits(await factory.getUniswapFeeTier(token.address), 4)}%`
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
        const token = getToken(taskArgs.address, factory.signer, hre)
        const symbol = await token.symbol()
        if (await factory.isRegisteredSettlementToken(token.address)) {
          console.log(chalk.red(`'${symbol} (${token.address})' is already registered token`))
          return
        }

        const decimals = await token.decimals()
        await (
          await factory.registerSettlementToken(
            token.address,
            parseUnits(taskArgs.minMargin.toString(), decimals),
            parseUnits(taskArgs.interestRate.toString(), 2),
            parseUnits(taskArgs.flashloanFeeRate.toString(), 2),
            parseUnits(taskArgs.earningDistributionThreshold.toString(), decimals),
            parseUnits(taskArgs.uniswapFeeRate.toString(), 4)
          )
        ).wait()
        console.log(
          chalk.green(`Success settlement token registration [${symbol}: ${token.address}]`)
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
        const token = getToken(taskArgs.address, factory.signer, hre)
        const symbol = await token.symbol()
        const decimals = await token.decimals()
        if (!(await factory.isRegisteredSettlementToken(token.address))) {
          console.log(chalk.red(`'${symbol} (${token.address})' is not registered token`))
          return
        }

        if (taskArgs.minMargin) {
          await factory.setMininumMargin(
            token.address,
            parseUnits(taskArgs.minMargin.toString(), decimals)
          )
          console.log(chalk.green('MinMargin is updated'))
        }
        if (taskArgs.flashloanFeeRate) {
          await factory.setFlashLoanFeeRate(
            token.address,
            parseUnits(taskArgs.flashloanFeeRate.toString(), 2)
          )
          console.log(chalk.green('FlashloanFeeRate is updated'))
        }
        if (taskArgs.earningDistributionThreshold) {
          await factory.setEarningDistributionThreshold(
            token.address,
            parseUnits(taskArgs.earningDistributionThreshold.toString(), decimals)
          )
          console.log(chalk.green('EarningDistributionThreshold is updated'))
        }
        if (taskArgs.uniswapFeeRate) {
          await factory.setUniswapFeeTier(
            token.address,
            parseUnits(taskArgs.uniswapFeeRate.toString(), 4)
          )
          console.log(chalk.green('UniswapFeeRate is updated'))
        }
      }
    )
  )
