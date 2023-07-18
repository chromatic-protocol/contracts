import { ChromaticMarketFactory } from '@chromatic/typechain-types'
import chalk from 'chalk'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
import { execute, findOracleProvider, findSettlementToken } from './utils'

task('market:create', 'Create new market')
  .addParam('chainlinkAddress', 'The chainlink feed aggregator address')
  .addParam('tokenAddress', 'The settlement token address or symbol')
  .setAction(
    execute(
      async (
        factory: ChromaticMarketFactory,
        taskArgs: TaskArguments,
        hre: HardhatRuntimeEnvironment
      ): Promise<any> => {
        const { chainlinkAddress, tokenAddress } = taskArgs

        const provider = await findOracleProvider(factory, chainlinkAddress)
        if (!provider) {
          console.log(
            chalk.red(`Cannot found oracle provider for chainlink feed '${chainlinkAddress}'`)
          )
          return
        }

        const token = await findSettlementToken(factory, tokenAddress)
        if (!token) {
          console.log(chalk.red(`Cannot found settlement token '${tokenAddress}'`))
          return
        }

        await (await factory.createMarket(await provider.getAddress(), await token.getAddress())).wait()

        console.log(
          chalk.green(
            `Success create new market [OracleProvider: ${await provider.getAddress()}, SettlementToken: ${await token.getAddress()}]`
          )
        )
      }
    )
  )
