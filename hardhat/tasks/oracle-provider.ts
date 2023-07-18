import { ChromaticMarketFactory } from '../..//typechain-types'
import chalk from 'chalk'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
import { execute, findOracleProvider } from './utils'

task('oracle-provider:register', 'Register oracle provider')
  .addParam('chainlinkAddress', 'The chainlink feed aggregator address')
  .setAction(
    execute(
      async (
        factory: ChromaticMarketFactory,
        taskArgs: TaskArguments,
        hre: HardhatRuntimeEnvironment
      ): Promise<any> => {
        const { deployments, getNamedAccounts } = hre
        const { chainlinkAddress } = taskArgs

        const provider = await findOracleProvider(factory, chainlinkAddress)
        if (provider) {
          console.log(
            chalk.blue(
              `Alreay registered oracle provider [OracleProvider: ${await provider.getAddress()}, ChainlinkFeedAggregator: ${chainlinkAddress}]`
            )
          )
          return
        }

        const { deployer } = await getNamedAccounts()
        const { address: providerAddress } = await deployments.deploy('ChainlinkFeedOracle', {
          from: deployer,
          args: [chainlinkAddress]
        })
        console.log(
          chalk.blue(`Deployed new oracle provider for chainlink feed '${chainlinkAddress}'`)
        )

        await (
          await factory.registerOracleProvider(providerAddress, {
            minTakeProfitBPS: 1000, // 10%
            maxTakeProfitBPS: 100000, // 1000%
            leverageLevel: 0
          })
        ).wait()

        console.log(
          chalk.green(
            `Success oracle provider registration [${providerAddress}, ChainlinkFeedAggregator: ${chainlinkAddress}]`
          )
        )
      }
    )
  )
