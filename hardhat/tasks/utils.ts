import {
  ChainlinkFeedOracle__factory,
  ChromaticMarketFactory,
  ChromaticMarketFactory__factory,
  IERC20Metadata,
  IERC20Metadata__factory,
  IOracleProvider,
  IOracleProvider__factory,
  PythFeedOracle__factory,
  SupraFeedOracle__factory
} from '@chromatic/typechain-types'
import { Token } from '@uniswap/sdk-core'
import { DAI_ON, USDC_ON, USDT_ON, WETH9 } from '@uniswap/smart-order-router'
import { ContractRunner, getAddress, isAddress } from 'ethers'
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

export async function findChainlinkOracleProvider(
  factory: ChromaticMarketFactory,
  chainlinkAddress: string
): Promise<IOracleProvider | undefined> {
  const providerAddresses = await factory.registeredOracleProviders()
  for (const providerAddress of providerAddresses) {
    const provider = IOracleProvider__factory.connect(providerAddress, factory.runner)
    if ((await provider.oracleProviderName()).toLowerCase() === 'chainlink') {
      if (
        chainlinkAddress.toLowerCase() ===
        (
          await ChainlinkFeedOracle__factory.connect(providerAddress, factory.runner).aggregator()
        ).toLowerCase()
      ) {
        return provider
      }
    }
  }
}

export async function findPythOracleProvider(
  factory: ChromaticMarketFactory,
  pythAddress: string,
  priceFeedId: string
): Promise<IOracleProvider | undefined> {
  const providerAddresses = await factory.registeredOracleProviders()
  for (const providerAddress of providerAddresses) {
    const provider = IOracleProvider__factory.connect(providerAddress, factory.runner)
    if ((await provider.oracleProviderName()).toLowerCase() === 'pyth') {
      const pythProvider = PythFeedOracle__factory.connect(providerAddress, factory.runner)
      const datas = await Promise.all([pythProvider.pyth(), pythProvider.priceFeedId()])
      if (
        datas[0].toLowerCase() === pythAddress.toLowerCase() &&
        datas[1].toLowerCase() === priceFeedId.toLowerCase()
      ) {
        return provider
      }
    }
  }
}

export async function findSupraOracleProvider(
  factory: ChromaticMarketFactory,
  supraAddress: string,
  pairIndex: bigint
): Promise<IOracleProvider | undefined> {
  const providerAddresses = await factory.registeredOracleProviders()
  for (const providerAddress of providerAddresses) {
    const provider = IOracleProvider__factory.connect(providerAddress, factory.runner)
    if ((await provider.oracleProviderName()).toLowerCase() === 'supra') {
      const supraProvider = SupraFeedOracle__factory.connect(providerAddress, factory.runner)
      const datas = await Promise.all([supraProvider.feed(), supraProvider.pairIndex()])
      if (datas[0].toLowerCase() === supraAddress.toLowerCase() && datas[1] === BigInt(pairIndex)) {
        return provider
      }
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

const WMNT: { [key: number]: string } = {
  5000: '0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8', // mantle
  5001: '0xea12be2389c2254baad383c6ed1fa1e15202b52a' // mantle_testnet
}

const TOKEN_SYMBOLS: Record<string, (chainId: keyof typeof WETH9) => Token> = {
  DAI: DAI_ON,
  USDC: USDC_ON,
  USDT: USDT_ON,
  WETH: (chainId) => {
    const weth = WETH9[chainId]
    if (weth) return weth
    throw new Error(`Chain id: ${chainId} not supported`)
  },
  WMNT: (chainId) => {
    const wmntAddress = WMNT[chainId]
    if (wmntAddress) {
      return new Token(chainId, wmntAddress, 18)
    }
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
    network.name === 'anvil'
      ? config.networks.arbitrum_goerli.chainId!
      : network.name === 'anvil_mantle'
      ? config.networks.mantle_testnet.chainId!
      : network.config.chainId!

  const tokenAddress = TOKEN_SYMBOLS[addressOrSymbol.toUpperCase()]
    ? TOKEN_SYMBOLS[addressOrSymbol.toUpperCase()](echainId).address
    : getAddress(addressOrSymbol)

  return IERC20Metadata__factory.connect(tokenAddress, runner)
}
