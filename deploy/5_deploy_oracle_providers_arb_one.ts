import chalk from 'chalk'
import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const CHAINLINK_AGGREGATORS: Record<string, string> = {
  BTC_USD: '0x6ce185860a4963106506C203335A2910413708e9',
  ETH_USD: '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612',
  USDT_USD: '0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7'
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
func.tags = ['oracle_providers_arb_one']
