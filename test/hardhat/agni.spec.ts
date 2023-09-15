import {
  AbstractPyth,
  AbstractPyth__factory,
  IAgniFactory__factory,
  IAgniPoolImmutables__factory,
  IAgniPoolState__factory,
  IAgniQuoterV2__factory,
  IAgniSwapRouter__factory,
  IERC20Metadata__factory,
  IERC20__factory,
  ISwapRouter__factory,
  IWETH9__factory,
  PythFeedOracle__factory
} from '@chromatic/typechain-types'
import { ethers } from 'hardhat'
import { expect } from 'chai'
import { getGasLimit } from '@chromatic/hardhat/tasks/utils'
import { BatchCallByFunctionNameParam, batchCallByFunctionName, mantleGetLogs } from './utils'
import { Indexed, JsonRpcProvider } from 'ethers'
import chalk from 'chalk'

// TODO ERC20 Deploy => Create Pool

// Mock ERC20 0x82A2eb46a64e4908bBC403854bc8AA699bF058E9
// mock USDT 0x2a821f808c27698ec9be07f584d1e370951fe42a
// 0x3e163f861826c3f7878bd8fa8117a179d80731ab

// mantle_testnet token list
// $GLDR: 0x92f6B08C3066EFA6c29539A6Dd23E89CFFe3faAD
// $USDC: 0xA11be02594AEF2AB383703D4ac7c7aD01767B30E
// $USDT: 0x541142baB3f0BcB5bB0DC1cb2C6dF0C88063d3FF
// $DAI: 0x62348104234DECba58b1Ee281503bC2D9ECBBf4d

type ChainAddresses = {
  agniFactory: string
  usdc: string
  usdt: string
  swapRouter: string
  quoterV2: string
  WMNT: string
}

const ADDRESSES: { [key: string]: ChainAddresses } = {
  mantle: {
    agniFactory: '0x25780dc8Fc3cfBD75F33bFDAB65e969b603b2035',
    usdc: '0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9', // WMNT(2500-50, 100-1) MNT-10000-200
    usdt: '0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE', // WMNT(10000-200 2500-50, 100-1,500-10) 100-1 10000-200 2500-50 500-10
    swapRouter: '0x319B69888b0d11cEC22caA5034e25FfFBDc88421',
    quoterV2: '0x49C8bb51C6bb791e8D6C31310cE0C14f68492991',
    WMNT: ''
  },
  mantle_testnet: {
    agniFactory: '0x503Ca2ad7C9C70F4157d14CF94D3ef5Fa96D7032',
    usdc: '0xA11be02594AEF2AB383703D4ac7c7aD01767B30E',
    usdt: '0x541142baB3f0BcB5bB0DC1cb2C6dF0C88063d3FF',
    swapRouter: '0xe2DB835566F8677d6889ffFC4F3304e8Df5Fc1df',
    quoterV2: '0x49C8bb51C6bb791e8D6C31310cE0C14f68492991',
    WMNT: '0xea12be2389c2254baad383c6ed1fa1e15202b52a'
  }
}

const MNT = '0xdeaddeaddeaddeaddeaddeaddeaddeaddead1111'

// https://explorer.mantle.xyz/api?module=logs&action=getLogs&fromBlock=0&toBlock=latest&address=0x25780dc8Fc3cfBD75F33bFDAB65e969b603b2035&topic0=0x783cca1c0412dd0d695e784568c96da2e9c22ff989357a2e8b1d9b2b4e6b7118
describe('agni test', async function () {
  it('pool state', async () => {
    const [signer] = await ethers.getSigners()
    const chain = (signer.provider as any)['_networkName']
    const addr = ADDRESSES[chain]

    const factory = IAgniFactory__factory.connect(addr.agniFactory, signer)

    const logs = await mantleGetLogs({
      address: addr.agniFactory,
      iface: factory.interface,
      eventName: 'PoolCreated'
    })

    const slot0Params: BatchCallByFunctionNameParam[] = []
    const token0BalanceParams: BatchCallByFunctionNameParam[] = []
    const token0DecimalParams: BatchCallByFunctionNameParam[] = []
    const token0SymbolParams: BatchCallByFunctionNameParam[] = []
    const token1BalanceParams: BatchCallByFunctionNameParam[] = []
    const token1DecimalParams: BatchCallByFunctionNameParam[] = []
    const token1SymbolParams: BatchCallByFunctionNameParam[] = []
    const erc20Iface = IERC20Metadata__factory.createInterface()
    const poolIface = IAgniPoolState__factory.createInterface()
    const from = await signer.getAddress()
    for (let i = 0; i < logs.length; i++) {
      const log = logs[i]
      const token0 = log[0]
      const token1 = log[1] // const fee = log[2] const tickSpacing = log[3]
      const pool = log[4]
      // prettier-ignore
      slot0Params.push({iface: poolIface, from, to: pool, functionName: 'slot0', data: []})
      // prettier-ignore
      token0BalanceParams.push({iface: erc20Iface, from, to: token0, functionName: 'balanceOf', data: [pool]})
      // prettier-ignore
      token1BalanceParams.push({iface: erc20Iface, from, to: token1, functionName: 'balanceOf', data: [pool]})
      // prettier-ignore
      token0DecimalParams.push({iface: erc20Iface, from, to: token0, functionName: 'decimals', data: []})
      // prettier-ignore
      token1DecimalParams.push({iface: erc20Iface, from, to: token1, functionName: 'decimals', data: []})
      // prettier-ignore
      token0SymbolParams.push({iface: erc20Iface, from, to: token0, functionName: 'symbol', data: []})
      // prettier-ignore
      token1SymbolParams.push({iface: erc20Iface, from, to: token1, functionName: 'symbol', data: []})
    }

    const slot0Arr = await batchCallByFunctionName(slot0Params)
    const token0Balances = await batchCallByFunctionName(token0BalanceParams)
    const token1Balances = await batchCallByFunctionName(token1BalanceParams)
    const token0Decimals = await batchCallByFunctionName(token0DecimalParams)
    const token1Decimals = await batchCallByFunctionName(token1DecimalParams)
    const token0Symbol = await batchCallByFunctionName(token0SymbolParams)
    const token1Symbol = await batchCallByFunctionName(token1SymbolParams)

    for (let i = 0; i < slot0Arr.length; i++) {
      const sqrtPriceX96 = slot0Arr[i][0]
      const ratio = Number(sqrtPriceX96) ** 2 / 2 ** 192

      console.log(
        chalk.yellow(`🫧  Pool: ${token0Symbol[i]} / ${token1Symbol[i]} ${slot0Params[i].to}`)
      )
      console.log(`sqrtPriceX96 ${ratio}`)
      console.log(`token0 - token1 ratio ${sqrtPriceX96}`)
      console.log(
        `Token0 : Total Tokens Locked ${token0Balances[i]}, Decimal ${token0Decimals[i]}, ${token0Symbol[i]}${token0BalanceParams[i].to}`
      )
      console.log(
        `Token1 : Total Tokens Locked ${token1Balances[i]}, Decimal ${token1Decimals[i]}, ${token1Symbol[i]}${token1BalanceParams[i].to}`
      )
    }
  })
  // it('swap', async () => {
  //   const [signer] = await ethers.getSigners()
  //   const chain = (signer.provider as any)['_networkName']
  //   const quoterV2 = IAgniQuoterV2__factory.connect(QUOTER_V2[chain], signer)

  //   // TODO Revert msg parsing
  //   // const output = await quoterV2.quoteExactOutputSingle.staticCall(
  //   //   {
  //   //     tokenIn: WMNT[chain],
  //   //     tokenOut: USDC[chain],
  //   //     amount: 123n * 10n ** 18n,
  //   //     fee: 3000,
  //   //     sqrtPriceLimitX96: 199
  //   //   },
  //   //   { gasLimit: '0x1000000' }
  //   // )
  //   // console.log(output)

  //   const from = await signer.getAddress()
  //   const router = IAgniSwapRouter__factory.connect(SWAP_ROUTER[chain], signer)
  //   const iweth9 = IWETH9__factory.connect(WMNT[chain], signer)
  //   const usdc = IERC20__factory.connect(USDC[chain], signer)
  //   // await (await iweth9.deposit({ value: 12345n * 10n ** 18n, gasLimit: '0x1000000' })).wait()

  //   console.log(await iweth9.balanceOf(from))
  //   console.log(await usdc.balanceOf(from))

  //   const swapTx = await router.exactOutputSingle(
  //     {
  //       tokenIn: WMNT[chain],
  //       tokenOut: USDC[chain],
  //       fee: 1000, // 10000 500 3000
  //       recipient: from,
  //       deadline: Math.ceil(Date.now() / 1000) + 30000,
  //       amountOut: 1n * 10n ** 18n,
  //       amountInMaximum: await iweth9.balanceOf(from),
  //       sqrtPriceLimitX96: 0
  //     },
  //     { gasLimit: '0x1000000' }
  //   )
  //   await swapTx.wait()
  //   console.log(await iweth9.balanceOf(from))
  //   console.log(await usdc.balanceOf(from))
  // })
}).timeout(60000)

// SWAP, CREATE POOL
export const getMinTick = (tickSpacing: number) => Math.ceil(-887272 / tickSpacing) * tickSpacing
export const getMaxTick = (tickSpacing: number) => Math.floor(887272 / tickSpacing) * tickSpacing
export const getMaxLiquidityPerTick = (tickSpacing: number) =>
  (2n ** 128n - 1n) / BigInt((getMaxTick(tickSpacing) - getMinTick(tickSpacing)) / tickSpacing + 1)
