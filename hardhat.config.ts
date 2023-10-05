import '@chromatic-protocol/hardhat-package'
import '@nomicfoundation/hardhat-ethers'
import '@nomicfoundation/hardhat-foundry'
import '@nomicfoundation/hardhat-toolbox'
import * as dotenv from 'dotenv'
import { JsonRpcProvider, Network } from 'ethers'
import 'hardhat-contract-sizer'
import 'hardhat-deploy'
import type { HardhatUserConfig } from 'hardhat/config'
import { extendProvider } from 'hardhat/config'
import { ProviderWrapper } from 'hardhat/plugins'
import { EIP1193Provider, HttpNetworkConfig, RequestArguments } from 'hardhat/types'
import 'solidity-docgen'
import 'tsconfig-paths/register'
import docgenConfig from './docs/docgen.config'
import packageConfig from './hardhat-package.config'

dotenv.config()

const MNEMONIC_JUNK = 'test test test test test test test test test test test junk'

const common = {
  accounts: {
    mnemonic: process.env.MNEMONIC || MNEMONIC_JUNK,
    count: 10
  }
}

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.19',
        settings: {
          optimizer: {
            enabled: true,
            runs: 30000
          }
        }
      }
    ]
  },
  mocha: {
    timeout: 400_000_000 // Error: Timeout of 40000ms exceeded. For async tests and hooks, ensure "done()" is called; if returning a Promise, ensure it resolves.
  },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      forking: {
        url: `https://arb-goerli.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
        blockNumber: 19474553
      },
      ...common,
      accounts: {
        ...common.accounts,
        mnemonic: MNEMONIC_JUNK
      },
      saveDeployments: false,
      allowUnlimitedContractSize: true
    },
    anvil: {
      // localhost anvil
      ...common,
      accounts: {
        ...common.accounts,
        mnemonic: MNEMONIC_JUNK
      },
      url: 'http://127.0.0.1:8545',
      chainId: 31337,
      allowUnlimitedContractSize: true,
      timeout: 100_000 // TransactionExecutionError: Headers Timeout Error
    },
    anvil_mantle: {
      // localhost anvil
      ...common,
      accounts: {
        ...common.accounts,
        mnemonic: MNEMONIC_JUNK
      },
      url: 'http://127.0.0.1:8545',
      chainId: 31338,
      allowUnlimitedContractSize: true,
      timeout: 100_000 // TransactionExecutionError: Headers Timeout Error
    },
    arbitrum_nova: {
      // mainnet AnyTrust chain
      ...common,
      url: 'https://nova.arbitrum.io/rpc',
      chainId: 42170
    },
    arbitrum_goerli: {
      // testnet
      ...common,
      url: `https://arb-goerli.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
      chainId: 421613
    },
    arbitrum_one: {
      // mainnet
      ...common,
      url: 'https://arb1.arbitrum.io/rpc',
      chainId: 42161
    },
    mantle: {
      ...common,
      url: `https://lb.drpc.org/ogrpc?network=mantle&dkey=${process.env.DRPC_KEY}`,
      chainId: 5000
    },
    mantle_testnet: {
      ...common,
      url: `https://lb.drpc.org/ogrpc?network=mantle-testnet&dkey=${process.env.DRPC_KEY}`,
      chainId: 5001
    }
  },
  namedAccounts: {
    deployer: {
      default: 0
    },
    gelato: 1,
    alice: 2,
    bob: 3,
    charlie: 4,
    david: 5,
    eve: 6,
    frank: 7,
    grace: 8,
    heidi: 9
  },
  package: packageConfig,
  docgen: docgenConfig,
  etherscan: {
    apiKey: {
      arbitrumGoerli: process.env.ARBISCAN_GOERLI_API_KEY!,
      mantleTestnet: 'test', // prevent MissingApiKeyError
      mantle: 'test' // prevent MissingApiKeyError
    },
    customChains: [
      {
        network: 'mantle',
        chainId: 5000,
        urls: {
          apiURL: 'https://explorer.mantle.xyz/api',
          browserURL: 'https://explorer.mantle.xyz/'
        }
      },
      {
        network: 'mantleTestnet',
        chainId: 5001,
        urls: {
          apiURL: 'https://explorer.testnet.mantle.xyz/api',
          browserURL: 'https://explorer.testnet.mantle.xyz/'
        }
      }
    ]
  }
}

class MantleProvider extends ProviderWrapper {
  private _jsonRpcProvider: JsonRpcProvider

  constructor(network: string, config: HttpNetworkConfig, _wrappedProvider: EIP1193Provider) {
    super(_wrappedProvider)
    this._jsonRpcProvider = new JsonRpcProvider(config.url, config.chainId, {
      staticNetwork: new Network(network, config.chainId!)
    })
  }

  public async request(args: RequestArguments) {
    if (args.method === 'eth_estimateGas') {
      return this._jsonRpcProvider.send(args.method, [(args.params as unknown[])[0]])
    }

    return this._wrappedProvider.request(args)
  }
}

extendProvider(async (provider, config, network) => {
  return network.startsWith('mantle')
    ? new MantleProvider(network, config.networks[network] as HttpNetworkConfig, provider)
    : provider
})

export default config
