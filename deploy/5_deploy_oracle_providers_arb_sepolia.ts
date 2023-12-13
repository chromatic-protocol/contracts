import chalk from 'chalk'
import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

const CHAINLINK_AGGREGATORS: Record<string, string> = {
  ETH_USD: '0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165',
  BTC_USD: '0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69'
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
func.tags = ['oracle_providers_arb_sepolia']
