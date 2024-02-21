import {
  ChromaticMarketFactory,
  ChromaticMarketFactory__factory,
  IERC20Metadata,
  IERC20Metadata__factory
} from '@chromatic/typechain-types'
import { Token } from '@uniswap/sdk-core'
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

const WETH: { [key: number]: string } = {
  42161: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
  421614: '0x980B62Da83eFf3D4576C647993b0c1D7faf17c73'
}

const WMNT: { [key: number]: string } = {
  5000: '0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8', // mantle
  5001: '0xea12be2389c2254baad383c6ed1fa1e15202b52a' // mantle_testnet
}

const TOKEN_SYMBOLS: Record<string, (chainId: number) => Token> = {
  // DAI: DAI_ON,
  // USDC: USDC_ON,
  // USDT: USDT_ON,
  WETH: (chainId) => {
    if (WETH[chainId]) {
      return new Token(chainId, WETH[chainId], 18)
    }
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
      ? config.networks.arbitrum_sepolia.chainId!
      : network.name === 'anvil_mantle'
      ? config.networks.mantle_testnet.chainId!
      : network.config.chainId!

  const tokenAddress = TOKEN_SYMBOLS[addressOrSymbol.toUpperCase()]
    ? TOKEN_SYMBOLS[addressOrSymbol.toUpperCase()](echainId).address
    : getAddress(addressOrSymbol)

  return IERC20Metadata__factory.connect(tokenAddress, runner)
}
