import {
  AbstractPyth,
  AbstractPyth__factory,
  PythFeedOracle__factory
} from '@chromatic/typechain-types'
import { ethers } from 'hardhat'
import { evmMainnet, evmTestnet } from './pythFeedIds'
import { expect } from 'chai'
import { batchCallByFunctionName, batchDeploy } from '../utils'

const IPYTH_ADDRESSES: { [key: string]: string } = {
  arbitrum_one: '0xff1a0f4744e8582DF1aE09D5611b887B6a12925C',
  arbitrum_goerli: '0x939C0e902FF5B3F7BA666Cc8F6aC75EE76d3f900',
  mantle: '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729',
  mantle_testnet: '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729',
  anvil: '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729'
}

const priceFeedIdsMap: { [key: string]: { [key: string]: string } } = {
  arbitrum_one: evmMainnet,
  arbitrum_goerli: evmTestnet,
  mantle: evmMainnet,
  mantle_testnet: evmTestnet,
  anvil: evmTestnet
}



describe('pyth test', async function () {
  var pyth: AbstractPyth
  var pythAddress: string
  var priceFeedIds: { [key: string]: string }
  before(async () => {
    const [signer] = await ethers.getSigners()
    const networkName = (signer.provider as any)['_networkName']
    if (IPYTH_ADDRESSES[networkName]) {
      pythAddress = IPYTH_ADDRESSES[networkName]
      console.log(networkName, pythAddress)
      pyth = AbstractPyth__factory.connect(pythAddress, signer)
      priceFeedIds = priceFeedIdsMap[networkName]
    }
  })

  it('price feed id test', async () => {
    // no backends available for method (Mantle)
    // const events = await ipyth.queryFilter(
    //   ipyth.filters['PriceFeedUpdate(bytes32,uint64,int64,uint64)']()
    // )
    const ethUsdId = priceFeedIds['Crypto.ETH/USD']
    const wrongId = `0x${'FF'.repeat(32)}`

    expect(await pyth.priceFeedExists(ethUsdId)).equal(true)
    expect(await pyth.priceFeedExists(wrongId)).equal(false)
  })

  // Anvil fork only
  it('PythOracleProvider deploy valid price feed id & decimal test', async () => {
    const [signer] = await ethers.getSigners()
    const from = await signer.getAddress()

    const iface = AbstractPyth__factory.createInterface()

    const priceFeedExists = await batchCallByFunctionName(
      Object.values(priceFeedIds).map((id) => ({
        iface,
        from,
        to: pythAddress,
        functionName: 'priceFeedExists',
        data: [id]
      }))
    )

    const ids: string[] = []
    const deployArgs = []

    for (let i = 0; i < priceFeedExists.length; i++) {
      const exist = priceFeedExists[i][0]
      if (exist) {
        ids.push(Object.values(priceFeedIds)[i])
        deployArgs.push([pythAddress, Object.values(priceFeedIds)[i], Object.keys(priceFeedIds)[i]])
      }
    }
    console.log('Exist price count', ids.length)

    const prices = await batchCallByFunctionName(
      Object.values(ids).map((id) => ({
        iface,
        from,
        to: pythAddress,
        functionName: 'getPriceUnsafe',
        data: [id]
      }))
    )

    const decimals = prices.map((p) => p[0][2]) as bigint[]
    const minDecimal = decimals.reduce((prev, curr) => (prev < curr ? prev : curr), 0n)
    const maxDecimal = decimals.reduce((prev, curr) => (prev < curr ? curr : prev), minDecimal)

    expect(maxDecimal).greaterThan(minDecimal)

    const pythFeedOracles = await batchDeploy({
      contract: 'PythFeedOracle',
      signer,
      args: deployArgs
    })

    console.log('deployed PythFeedOracle count :', pythFeedOracles.length)

    const pythPriceFeedOracleFactory = (await ethers.getContractFactory('PythFeedOracle')).interface

    const currentVersions = await batchCallByFunctionName(
      pythFeedOracles.map((to: string) => ({
        iface: pythPriceFeedOracleFactory,
        from,
        to,
        functionName: 'currentVersion',
        data: []
      }))
    )

    const originPrices = prices.map((p) => p[0][0] * 10n ** (18n + p[0][2]))
    const oraclePrices = currentVersions.map((v) => v[0][2])
    expect(originPrices).to.deep.equal(oraclePrices)
  })
})
