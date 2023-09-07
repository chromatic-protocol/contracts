import { ChromaticMarketFactory, IPyth__factory } from '@chromatic/typechain-types'
import chalk from 'chalk'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
import { execute, findChainlinkOracleProvider, findPythOracleProvider } from './utils'

// yarn hardhat:mantle_testnet oracle-provider:register --chainlink-address '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729'
// yarn hardhat:mantle_testnet oracle-provider:register --pyth-address '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729'
// yarn hardhat:mantle_testnet oracle-provider:register --pyth-address '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729' --price-feed-id '0xca80ba6dc32e08d06f1aa886011eed1d77c77be9eb761cc10d72b7d0a2fd57a6' --description 'ETH/USD'

// yarn hardhat:arbitrum_goerli oracle-provider:register --chainlink-address '0x62CAe0FA2da220f43a51F86Db2EDb36DcA9A5A08'
// yarn hardhat:arbitrum_goerli oracle-provider:register --pyth-address '0x939C0e902FF5B3F7BA666Cc8F6aC75EE76d3f900'
// yarn hardhat:arbitrum_goerli oracle-provider:register --pyth-address '0x939C0e902FF5B3F7BA666Cc8F6aC75EE76d3f900' --price-feed-id '0xca80ba6dc32e08d06f1aa886011eed1d77c77be9eb761cc10d72b7d0a2fd57a6' --description 'ETH/USD'

task('oracle-provider:register', 'Register oracle provider')
  .addOptionalParam('chainlinkAddress', 'The chainlink feed aggregator address')
  .addOptionalParam('pythAddress', 'The pyth price feed address')
  .addOptionalParam('priceFeedId', 'The price feed id of pyth')
  .addOptionalParam('description', 'The price feed description')
  .setAction(
    execute(
      async (
        factory: ChromaticMarketFactory,
        taskArgs: TaskArguments,
        hre: HardhatRuntimeEnvironment
      ): Promise<any> => {
        const { deployments, getNamedAccounts, ethers } = hre
        const { deployer } = await getNamedAccounts()

        const networkBase = hre.network.name.split('_')[0].toLowerCase()

        const { chainlinkAddress, pythAddress, priceFeedId, description } = taskArgs

        // pyth only for mantle
        if (networkBase === 'mantle' && !(pythAddress && priceFeedId && description)) {
          console.log(chalk.red(`--pyth-address , --price-feed-id and --description are required`))
          return
        }

        // network check
        if (networkBase !== 'mantle' && networkBase !== 'arbitrum') {
          console.log(chalk.red(`unsupported chain`))
          return
        }

        // param check
        if (!chainlinkAddress && !(pythAddress && priceFeedId && description)) {
          console.log(chalk.red(`invaild param`))
          return
        }

        const infoString = chainlinkAddress
          ? `ChainlinkFeedAggregator: ${chainlinkAddress}`
          : `Pyth: ${pythAddress}, priceFeedId: ${priceFeedId}`

        const provider = chainlinkAddress
          ? await findChainlinkOracleProvider(factory, chainlinkAddress)
          : await findPythOracleProvider(factory, pythAddress, priceFeedId)

        if (provider) {
          console.log(
            chalk.blue(
              `Alreay registered oracle provider [OracleProvider: ${await provider.getAddress()}, ${infoString}]`
            )
          )
          return
        }

        const deployResult = chainlinkAddress
          ? await deployments.deploy('ChainlinkFeedOracle', {
              from: deployer,

              args: [chainlinkAddress]
            })
          : await deployments.deploy('PythFeedOracle', {
              from: deployer,
              args: [pythAddress, priceFeedId, description]
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
