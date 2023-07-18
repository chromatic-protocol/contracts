import {
  ChromaticMarketFactory,
  ChromaticMarketFactory__factory,
  IERC20Metadata,
  IERC20Metadata__factory,
  IOracleProvider,
  IOracleProvider__factory
} from '@chromatic/typechain-types'
import { Token } from '@uniswap/sdk-core'
import { DAI_ON, ID_TO_CHAIN_ID, USDC_ON, USDT_ON, WETH9 } from '@uniswap/smart-order-router'
import { ContractRunner, ethers, getAddress, isAddress } from 'ethers'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'

export function execute(
  action: (
    factory: ChromaticMarketFactory,
    taskArgs: TaskArguments,
    hre: HardhatRuntimeEnvironment
  ) => Promise<any>
): (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment) => Promise<any> {
  return async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment): Promise<any> => {
    const { deployments, ethers } = hre

    const signer = (await ethers.getSigners())[0]

    const { address: marketFactoryAddress } = await deployments.get('ChromaticMarketFactory')
    const factory = ChromaticMarketFactory__factory.connect(marketFactoryAddress, signer)

    return action(factory, taskArgs, hre)
  }
}

export async function findOracleProvider(
  factory: ChromaticMarketFactory,
  chainlinkAddress: string
): Promise<IOracleProvider | undefined> {
  const abi = [
    {
      inputs: [],
      name: 'aggregator',
      outputs: [
        {
          internalType: 'ChainlinkAggregator',
          name: '',
          type: 'address'
        }
      ],
      stateMutability: 'view',
      type: 'function'
    }
  ]

  const providerAddresses = await factory.registeredOracleProviders()
  for (const providerAddress of providerAddresses) {
    const provider = new ethers.Contract(providerAddress, abi, factory.runner)
    if (chainlinkAddress.toLowerCase() == (await provider.aggregator()).toLowerCase()) {
      return IOracleProvider__factory.connect(providerAddress, factory.runner)
    }
  }
}

export async function findSettlementToken(
  factory: ChromaticMarketFactory,
  tokenAddressOrSymbol: string
): Promise<IERC20Metadata | undefined> {
  const tokenAddresses = await factory.registeredSettlementTokens()
  for (const tokenAddress of tokenAddresses) {
    const token = IERC20Metadata__factory.connect(tokenAddress, factory.runner)
    // avoid Property 'toLowerCase' does not exist on type 'never'. else block
    const tokenAddressOrSymbolLowerCase = tokenAddressOrSymbol.toLowerCase()
    if (isAddress(tokenAddressOrSymbol)) {
      if (tokenAddressOrSymbolLowerCase == (await token.getAddress()).toLowerCase()) {
        return token
      }
    } else {
      if (tokenAddressOrSymbolLowerCase == (await token.symbol()).toLowerCase()) {
        return token
      }
    }
  }
}

const TOKEN_SYMBOLS: Record<string, (chainId: keyof typeof WETH9) => Token> = {
  DAI: DAI_ON,
  USDC: USDC_ON,
  USDT: USDT_ON,
  WETH: (chainId) => {
    const weth = WETH9[chainId]
    if (weth) return weth
    throw new Error(`Chain id: ${chainId} not supported`)
  }
}

export function getToken(
  addressOrSymbol: string,
  runner: ContractRunner | null,
  hre: HardhatRuntimeEnvironment
): IERC20Metadata {
  const { config, network } = hre
  const echainId =
    network.name === 'anvil' ? config.networks.arbitrum_goerli.chainId! : network.config.chainId!
  const chainId = ID_TO_CHAIN_ID(echainId) as keyof typeof WETH9

  const tokenAddress = TOKEN_SYMBOLS[addressOrSymbol.toUpperCase()]
    ? TOKEN_SYMBOLS[addressOrSymbol.toUpperCase()](chainId).address
    : getAddress(addressOrSymbol)

  return IERC20Metadata__factory.connect(tokenAddress, runner)
}
