import fs from 'fs'
import Mustache from 'mustache'

import { join } from 'path'

const abiPath = join('.', 'abis')
const deployments = join('..', '..', 'deployments')

async function loadDeployment(network, contract) {
  const json = await import(join(deployments, network, `${contract}.json`), {
    assert: { type: 'json' }
  })
  return json.default
}

function saveABI(contract, deployment) {
  if (!fs.existsSync(abiPath)) fs.mkdirSync(abiPath, { recursive: true })
  fs.writeFileSync(join(abiPath, `${contract}.json`), JSON.stringify(deployment.abi, null, 2))
}

async function loadABIFromArtifacts(interfaceName, path) {
  const interfacesPath = join(...'../../artifacts'.split('/'), ...path.split('/'))
  const json = await import(join(interfacesPath, `${interfaceName}.sol`, `${interfaceName}.json`), {
    assert: { type: 'json' }
  })
  return json.default
}

async function saveABIFromArtifacts(interfaceName, path) {
  if (!fs.existsSync(abiPath)) fs.mkdirSync(abiPath, { recursive: true })
  const json = await loadABIFromArtifacts(interfaceName, path)

  fs.writeFileSync(join(abiPath, `${interfaceName}.json`), JSON.stringify(json.abi, null, 2))
}

async function main() {
  const network = process.argv[2]
  const templateFile = process.argv[3]
  const outputFile = process.argv[4]

  const factory = await loadDeployment(network, 'ChromaticMarketFactory')
  const router = await loadDeployment(network, 'ChromaticRouter')

  saveABI('ChromaticMarketFactory', factory)
  await saveABIFromArtifacts('IERC20Metadata', '@openzeppelin/contracts/token/ERC20/extensions')
  await saveABIFromArtifacts('IOracleProvider', 'contracts/oracle/interfaces')
  await saveABIFromArtifacts('IOracleProviderPullBased', 'contracts/oracle/interfaces')
  await saveABIFromArtifacts('IChromaticMarket', 'contracts/core/interfaces')
  await saveABIFromArtifacts('ICLBToken', 'contracts/core/interfaces')

  saveABI('ChromaticRouter', router)
  await saveABIFromArtifacts('IChromaticAccount', 'contracts/periphery/interfaces')

  const template = fs.readFileSync(templateFile).toString()
  const output = Mustache.render(template, {
    network: network === 'mantle_testnet' ? 'testnet' : network,
    ChromaticMarketFactory: factory.address,
    ChromaticMarketFactory_blockNumber: factory.receipt.blockNumber,
    ChromaticRouter: router.address,
    ChromaticRouter_blockNumber: router.receipt.blockNumber
  })
  fs.writeFileSync(outputFile, output)

  console.log('✅  Prepared', outputFile)
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
