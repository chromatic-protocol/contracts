import { ChromaticMarketFactory } from '@chromatic/typechain-types'
import chalk from 'chalk'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
import {
  execute,
  findChainlinkOracleProvider,
  findPythOracleProvider,
  findSettlementToken,
  getGasLimit
} from './utils'

task('market:create', 'Create new market')
  .addOptionalParam('chainlinkAddress', 'The chainlink feed aggregator address')
  .addOptionalParam('pythAddress', 'The pyth price feed address')
  .addOptionalParam('priceFeedId', 'The price feed id of pyth')
  .addParam('tokenAddress', 'The settlement token address or symbol')
  .setAction(
    execute(
      async (
        factory: ChromaticMarketFactory,
        taskArgs: TaskArguments,
        hre: HardhatRuntimeEnvironment
      ): Promise<any> => {
        const { chainlinkAddress, pythAddress, priceFeedId, tokenAddress } = taskArgs

        // param check
        if (!chainlinkAddress && !(pythAddress && priceFeedId)) {
          console.log(chalk.red(`invaild param`))
          return
        }

        const provider = chainlinkAddress
          ? await findChainlinkOracleProvider(factory, chainlinkAddress)
          : await findPythOracleProvider(factory, pythAddress, priceFeedId)
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

        await (
          await factory.createMarket(await provider.getAddress(), await token.getAddress(), {
            gasLimit: getGasLimit(hre)
          })
        ).wait()

        console.log(
          chalk.green(
            `Success create new market [OracleProvider: ${await provider.getAddress()}, SettlementToken: ${await token.getAddress()}]`
          )
        )
      }
    )
  )
