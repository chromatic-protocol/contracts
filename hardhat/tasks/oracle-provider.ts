import { ChromaticMarketFactory, IPyth__factory } from '@chromatic/typechain-types'
import chalk from 'chalk'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
import { execute, findOracleProvider } from './utils'

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

        let providerAddress: string

        if (networkBase === 'mantle') {
          // use Pyth
          const { pythAddress, priceFeedId, description } = taskArgs
          if (!pythAddress || !priceFeedId || !description) {
            throw Error('--pyth-address , --price-feed-id and --description  is required')
          }

          const signer = (await ethers.getSigners())[0]
          const ipyth = IPyth__factory.connect(pythAddress, signer)
          if (!(await ipyth.priceFeedExists(priceFeedId))) {
            throw Error('invaild price feed id')
          }

          const { address: pythProviderAddress } = await deployments.deploy('PythFeedOracle', {
            from: deployer,
            args: [pythAddress, priceFeedId, description]
          })
          providerAddress = pythProviderAddress

        } else if (networkBase === 'arbitrum') {
          const { chainlinkAddress } = taskArgs
          if (!chainlinkAddress) {
            throw Error('--chainlink-address is required')
          }

          const provider = await findOracleProvider(factory, chainlinkAddress)
          if (provider) {
            console.log(
              chalk.blue(
                `Alreay registered oracle provider [OracleProvider: ${await provider.getAddress()}, ChainlinkFeedAggregator: ${chainlinkAddress}]`
              )
            )
            return
          }

          const { address: chainlinkProviderAddress } = await deployments.deploy(
            'ChainlinkFeedOracle',
            {
              from: deployer,

              args: [chainlinkAddress]
            }
          )
          providerAddress = chainlinkProviderAddress
          console.log(
            chalk.blue(`Deployed new oracle provider for chainlink feed '${chainlinkAddress}'`)
          )
        } else {
          throw Error('unsupported chain')
        }

        await (
          await factory.registerOracleProvider(providerAddress!, {
            minTakeProfitBPS: 1000, // 10%
            maxTakeProfitBPS: 100000, // 1000%
            leverageLevel: 0
          })
        ).wait()

        // TODO
        // console.log(
        //   chalk.green(
        //     `Success oracle provider registration [${providerAddress!}, ChainlinkFeedAggregator: ${chainlinkAddress}]`
        //   )
        // )
      }
    )
  )
