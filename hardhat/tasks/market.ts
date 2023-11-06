import { ChromaticMarketFactory } from '@chromatic/typechain-types'
import chalk from 'chalk'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
import { execute, findSettlementToken } from './utils'

task('market:create', 'Create new market')
  .addParam('oracleProvider', 'The deployed oracle provider address')
  .addParam('tokenAddress', 'The settlement token address or symbol')
  .setAction(
    execute(
      async (
        factory: ChromaticMarketFactory,
        taskArgs: TaskArguments,
        hre: HardhatRuntimeEnvironment
      ): Promise<any> => {
        const { deployments } = hre

        const { oracleProvider, tokenAddress } = taskArgs
        const { address: oracleProviderAddress } = await deployments.get(oracleProvider)

        if (!(await factory.isRegisteredOracleProvider(oracleProviderAddress))) {
          console.log(
            chalk.blue(
              `Not registered oracle provider [${oracleProvider}: ${oracleProviderAddress}]`
            )
          )
          return
        }

        const token = await findSettlementToken(factory, tokenAddress)
        if (!token) {
          console.log(chalk.red(`Cannot found settlement token '${tokenAddress}'`))
          return
        }

        await (await factory.createMarket(oracleProviderAddress, await token.getAddress())).wait()

        console.log(
          chalk.green(
            `Success create new market [${oracleProvider}: ${oracleProviderAddress}, SettlementToken: ${await token.getAddress()}]`
          )
        )
      }
    )
  )
