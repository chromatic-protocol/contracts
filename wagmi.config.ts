import { defineConfig } from '@wagmi/cli'
import { hardhat } from '@wagmi/cli/plugins'
import packageConfig from './hardhat-package.config'
import { deployedAddress } from './package-build-v5/src.ts/deployedAddress'

function getDeployments(packageConfig: any) {
  const contracts = packageConfig?.includesFromDeployed

  const deployments = {}
  const chainNames = Object.keys(deployedAddress)
  const chainIds = {
    anvil: 31337,
    arbitrum_sepolia: 421614,
    arbitrum_one: 42161,
    mantle: 5000,
    mantle_testnet: 5001
  }

  for (let contract of contracts) {
    const deployment = {}
    for (let chain of chainNames) {
      const address = deployedAddress[chain]?.[contract]
      if (address) {
        deployment[chainIds[chain]] = address
      }
    }
    deployments[contract] = deployment
  }
  console.log('deployments:', deployments)
  return deployments
}

const deployments = getDeployments(packageConfig)

export default defineConfig({
  out: 'wagmi/index.ts',
  plugins: [
    hardhat({
      project: '.',
      include: packageConfig.includes,
      exclude: packageConfig.excludes,
      deployments: deployments
    })
  ]
})
