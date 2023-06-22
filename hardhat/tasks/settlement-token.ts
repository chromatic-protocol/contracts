import { ChromaticMarketFactory } from '@chromatic/typechain-types'
import chalk from 'chalk'
import { BigNumber } from 'ethers'
import { parseUnits } from 'ethers/lib/utils'
import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
import { execute, getToken } from './utils'

task('settlement-token:register', 'Register settlement token')
  .addParam('address', 'The settlement token address or symbol')
  .addParam('minMargin', 'The minimum margin for trading', 10, types.int)
  .addParam('interestRate', 'The annual interest rate as a percentage', 10, types.int)
  .addParam('flashloanFeeRate', 'The flashloan fee rate as a percentage', 5, types.int)
  .addParam('earningDistributionThreshold', 'The earning distribution threshold', 1000, types.int)
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
            BigNumber.from(taskArgs.interestRate * 100),
            BigNumber.from(taskArgs.flashloanFeeRate * 100),
            parseUnits(taskArgs.earningDistributionThreshold.toString(), decimals),
            BigNumber.from(taskArgs.uniswapFeeRate * 10000)
          )
        ).wait()
        console.log(
          chalk.green(`Success settlement token registration [${symbol}: ${token.address}]`)
        )
      }
    )
  )
