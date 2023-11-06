import chalk from 'chalk'
import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const CHAINLINK_AGGREGATORS: Record<string, string> = {
  ETH_USD: '0x62CAe0FA2da220f43a51F86Db2EDb36DcA9A5A08',
  BTC_USD: '0x6550bc2301936011c1334555e62A87705A81C12C'
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
}

export default func

func.id = 'deploy_oracle_providers'
func.tags = ['oracle_providers_arbitrum']
