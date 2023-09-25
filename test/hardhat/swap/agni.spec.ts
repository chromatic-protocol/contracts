import { IERC20Metadata__factory } from '@chromatic/typechain-types'
import { ethers } from 'hardhat'
import { mantleGetLogs, setChain } from '../utils'
import chalk from 'chalk'
import { Contract, Interface } from 'ethers'

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
    WMNT: '0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8'
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

export function agniTest() {
  describe('Swap pool state log', async function () {
    // yarn hardhat test --grep 'AGNI pool state' --network mantle
    it('AGNI pool state', async () => {
      const testTarget = 'mantle_testnet'
      await setChain(testTarget)
      const [signer] = await ethers.getSigners()
      const addr = ADDRESSES[testTarget]

      const factoryIface = new Interface(factoryAbi)

      // ProviderError: Fork Error: JsonRpcClientError(JsonRpcError(JsonRpcError { code: -32011, message: "no backends available for method", data: None }))
      const logs = await mantleGetLogs({
        address: addr.agniFactory,
        iface: factoryIface,
        eventName: 'PoolCreated',
        toBlock: await signer.provider.getBlockNumber()
      })

      const slot0s = await Promise.all(
        logs.map((log) => new Contract(log[4], poolAbi, signer).slot0())
      )

      const token0Balances = await Promise.all(
        logs.map((log) => IERC20Metadata__factory.connect(log[0], signer).balanceOf(log[4]))
      )
      const token1Balances = await Promise.all(
        logs.map((log) => IERC20Metadata__factory.connect(log[1], signer).balanceOf(log[4]))
      )

      const token0Decimals = await Promise.all(
        logs.map((log) => IERC20Metadata__factory.connect(log[0], signer).decimals())
      )

      const token1Decimals = await Promise.all(
        logs.map((log) => IERC20Metadata__factory.connect(log[1], signer).decimals())
      )
      const token0Symbol = await Promise.all(
        logs.map((log) => IERC20Metadata__factory.connect(log[0], signer).symbol())
      )
      const token1Symbol = await Promise.all(
        logs.map((log) => IERC20Metadata__factory.connect(log[1], signer).symbol())
      )

      const fees = logs.map((log) => log[2])

      for (let i = 0; i < slot0s.length; i++) {
        const sqrtPriceX96 = slot0s[i][0]
        const ratio = Number(sqrtPriceX96) ** 2 / 2 ** 192
        const decimalGap = Number(token1Decimals[i]) - Number(token0Decimals[i])
        const token1Price = ratio / 10 ** decimalGap
        const token2Price = 1 / token1Price

        console.log(
          chalk.yellow(
            `🫧  Pool: ${token0Symbol[i]} / ${token1Symbol[i]} ${fees[i]} - ${logs[i][4]}`
          )
        )
        console.log(`sqrtPriceX96 ${sqrtPriceX96}`)
        console.log(`token0 - token1 ratio ${ratio}`)
        console.log(`1 ${token0Symbol[i]} = ${token1Price} ${token1Symbol[i]}`)
        console.log(`1 ${token1Symbol[i]} = ${token2Price} ${token0Symbol[i]}`)

        console.log(
          `Token0 : Total Tokens Locked ${token0Balances[i]}, Decimal ${token0Decimals[i]}, ${token0Symbol[i]} ${logs[i][0]}`
        )
        console.log(
          `Token1 : Total Tokens Locked ${token1Balances[i]}, Decimal ${token1Decimals[i]}, ${token1Symbol[i]} ${logs[i][1]}`
        )
      }
    })
  }).timeout(60000)
}

const poolAbi = [
  {
    inputs: [],
    name: 'slot0',
    outputs: [
      {
        internalType: 'uint160',
        name: 'sqrtPriceX96',
        type: 'uint160'
      },
      {
        internalType: 'int24',
        name: 'tick',
        type: 'int24'
      },
      {
        internalType: 'uint16',
        name: 'observationIndex',
        type: 'uint16'
      },
      {
        internalType: 'uint16',
        name: 'observationCardinality',
        type: 'uint16'
      },
      {
        internalType: 'uint16',
        name: 'observationCardinalityNext',
        type: 'uint16'
      },
      {
        internalType: 'uint8',
        name: 'feeProtocol',
        type: 'uint8'
      },
      {
        internalType: 'bool',
        name: 'unlocked',
        type: 'bool'
      }
    ],
    stateMutability: 'view',
    type: 'function'
  }
]
const factoryAbi = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'address',
        name: 'token0',
        type: 'address'
      },
      {
        indexed: true,
        internalType: 'address',
        name: 'token1',
        type: 'address'
      },
      {
        indexed: true,
        internalType: 'uint24',
        name: 'fee',
        type: 'uint24'
      },
      {
        indexed: false,
        internalType: 'int24',
        name: 'tickSpacing',
        type: 'int24'
      },
      {
        indexed: false,
        internalType: 'address',
        name: 'pool',
        type: 'address'
      }
    ],
    name: 'PoolCreated',
    type: 'event'
  }
]
