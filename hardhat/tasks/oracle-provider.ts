import { ChromaticMarketFactory, IOracleProvider, IPyth__factory } from '@chromatic/typechain-types'
import chalk from 'chalk'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
import {
  execute,
  findChainlinkOracleProvider,
  findPythOracleProvider,
  findSupraOracleProvider
} from './utils'

// USAGE
// yarn hardhat:arbitrum_goerli oracle-provider:register --chainlink-address '0x62CAe0FA2da220f43a51F86Db2EDb36DcA9A5A08'
// yarn hardhat:mantle_testnet oracle-provider:register --pyth-address '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729' --price-feed-id '0xca80ba6dc32e08d06f1aa886011eed1d77c77be9eb761cc10d72b7d0a2fd57a6' --description 'ETH/USD'
// yarn hardhat:mantle_testnet oracle-provider:register --supra-address '0x4Ce261C19af540f1175CdeB9E3490DC8937D78e5' --pair-index 19 --description 'ETH/USD'
task('oracle-provider:register', 'Register oracle provider')
  .addOptionalParam('chainlinkAddress', 'The chainlink feed aggregator address')
  .addOptionalParam('pythAddress', 'The pyth price feed address')
  .addOptionalParam('priceFeedId', 'The price feed id of pyth')
  .addOptionalParam('supraAddress', 'The price feed id of supra')
  .addOptionalParam('pairIndex', 'The price feed id of supra')
  .addOptionalParam('description', 'The price feed description')
  .setAction(
    execute(
      async (
        factory: ChromaticMarketFactory,
        taskArgs: TaskArguments,
        hre: HardhatRuntimeEnvironment
      ): Promise<any> => {
        const { deployments, getNamedAccounts } = hre
        const { deployer } = await getNamedAccounts()

        const { chainlinkAddress, pythAddress, priceFeedId, description, supraAddress, pairIndex } =
          taskArgs

        let infoString: string
        let provider: IOracleProvider | undefined
        let contractName: string
        let deployArgs: any[]
        if (chainlinkAddress) {
          // chainlink
          infoString = `ChainlinkFeedAggregator: ${chainlinkAddress}`
          provider = await findChainlinkOracleProvider(factory, chainlinkAddress)
          contractName = 'ChainlinkFeedOracle'
          deployArgs = [chainlinkAddress]
        } else if (pythAddress && priceFeedId && description) {
          // pyth
          infoString = `Pyth: ${pythAddress}, priceFeedId: ${priceFeedId}`
          provider = await findPythOracleProvider(factory, pythAddress, priceFeedId)
          contractName = 'PythFeedOracle'
          deployArgs = [pythAddress, priceFeedId, description]
        } else if (supraAddress && pairIndex && description) {
          // supra
          infoString = `Supra: ${supraAddress}, pairIndex: ${pairIndex}`
          provider = await findSupraOracleProvider(factory, supraAddress, pairIndex)
          contractName = 'SupraFeedOracle'
          deployArgs = [supraAddress, pairIndex, description]
        } else {
          console.log(chalk.red(`invaild param`))
          return
        }

        if (provider) {
          console.log(
            chalk.blue(
              `Alreay registered oracle provider [OracleProvider: ${await provider.getAddress()}, ${infoString}]`
            )
          )
          return
        }

        const deployResult = await deployments.deploy(contractName, {
          from: deployer,
          args: deployArgs
        })

        console.log(
          chalk.blue(
            `Deployed new oracle provider [OracleProvider: ${deployResult.address}, ${infoString}]`
          )
        )

        await (
          await factory.registerOracleProvider(deployResult.address!, {
            minTakeProfitBPS: 1000, // 10%
            maxTakeProfitBPS: 100000, // 1000%
            leverageLevel: 0
          })
        ).wait()

        console.log(
          chalk.green(
            `Success oracle provider registration [${deployResult.address!}, ${infoString}]`
          )
        )
      }
    )
  )
