import { ChromaticMarketFactory } from '@chromatic/typechain-types'
import chalk from 'chalk'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
import { execute } from './utils'

task('oracle-provider:register', 'Register oracle provider')
  .addParam('oracleProvider', 'The deployed oracle provider address')
  .setAction(
    execute(
      async (
        factory: ChromaticMarketFactory,
        taskArgs: TaskArguments,
        hre: HardhatRuntimeEnvironment
      ): Promise<any> => {
        const { deployments } = hre

        const { oracleProvider } = taskArgs
        const { address: oracleProviderAddress } = await deployments.get(oracleProvider)

        if (await factory.isRegisteredOracleProvider(oracleProviderAddress)) {
          console.log(
            chalk.blue(
              `Alreay registered oracle provider [${oracleProvider}: ${oracleProviderAddress}]`
            )
          )
          return
        }

        await (
          await factory.registerOracleProvider(oracleProviderAddress, {
            minTakeProfitBPS: 200, // 2%
            maxTakeProfitBPS: 100000, // 1000%
            leverageLevel: 0
          })
        ).wait()

        console.log(
          chalk.green(
            `Success oracle provider registration [${oracleProvider}: ${oracleProviderAddress}]`
          )
        )
      }
    )
  )
