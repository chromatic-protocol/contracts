import chalk from 'chalk'
import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const CHAINLINK_AGGREGATORS: Record<string, string> = {
  ETH_USD: '0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165',
  BTC_USD: '0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69'
}

const PYTH_ADDRESSES: { [key: number]: string } = {
  421614: '0x4374e5a8b9c22271e9eb878a2aa31de97df15daf',
  42161: '0xff1a0f4744e8582DF1aE09D5611b887B6a12925C'
}

const PYTH_PRICE_FEED_IDS: Record<string, { feedId: string; description: string }> = {
  BTC_USD: {
    feedId: '0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43',
    description: 'BTC/USD'
  }
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { config, deployments, getNamedAccounts, ethers, network } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  for (const [name, address] of Object.entries(CHAINLINK_AGGREGATORS)) {
    const oracleProviderName = `OracleProvider_${name}`
    const { address: oracleProviderAddress } = await deploy(oracleProviderName, {
      contract: 'ChainlinkFeedOracle',
      args: [address],
      from: deployer
    })

    console.log(chalk.yellow(`✨ ${oracleProviderName}: ${oracleProviderAddress}`))
  }

  for (const [name, info] of Object.entries(PYTH_PRICE_FEED_IDS)) {
    const oracleProviderName = `PythOracleProvider_${name}`
    const { address: oracleProviderAddress } = await deploy(oracleProviderName, {
      contract: 'PythFeedOracle',
      args: [PYTH_ADDRESSES[network.config.chainId!], info.feedId, info.description],
      from: deployer
    })

    console.log(chalk.yellow(`✨ ${oracleProviderName}: ${oracleProviderAddress}`))
  }
}

export default func

func.id = 'deploy_oracle_providers'
func.tags = ['oracle_providers_arb_sepolia']
