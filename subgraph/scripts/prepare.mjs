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

async function main() {
  const network = process.argv[2]
  const templateFile = process.argv[3]
  const outputFile = process.argv[4]

  const router = await loadDeployment(network, 'ChromaticRouter')

  saveABI('ChromaticRouter', router)

  const template = fs.readFileSync(templateFile).toString()
  const output = Mustache.render(template, {
    network: network === 'mantle_testnet' ? 'testnet' : network,
    blockNumber: router.receipt.blockNumber,
    ChromaticRouter: router.address
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
