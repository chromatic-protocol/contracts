import { PythFeedOracle } from '@chromatic/typechain-types'
import { ethers } from 'hardhat'
import { forkingOptions } from '../../utils'
import { evmMainnet, evmTestnet } from '../pythFeedIds'

const IPYTH_ADDRESSES: { [key: string]: string } = {
  arbitrum_one: '0xff1a0f4744e8582DF1aE09D5611b887B6a12925C',
  arbitrum_sepolia: '0x4374e5a8b9C22271E9EB878A2AA31DE97DF15DAF',
  mantle: '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729',
  mantle_testnet: '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729'
}

const priceFeedIdsMap: { [key: string]: { [key: string]: string } } = {
  arbitrum_one: evmMainnet,
  arbitrum_sepolia: evmMainnet, // arbitrum sepolia use mainnet ids
  mantle: evmMainnet,
  mantle_testnet: evmTestnet
}

export function spec(networkName: keyof typeof forkingOptions) {
  describe('pyth test', async function () {
    let pythOracleProvider: PythFeedOracle
    let pythAddress: string
    let btcUsdId: string
    before(async () => {
      pythAddress = IPYTH_ADDRESSES[networkName]

      btcUsdId = priceFeedIdsMap[networkName]['Crypto.BTC/USD']

      const pythFeedOracleF = await ethers.getContractFactory('PythFeedOracle')
      pythOracleProvider = await pythFeedOracleF.deploy(pythAddress, btcUsdId, 'BTC/USD')
      // pythOracleProvider.
    })

    it('update price', async () => {
      //pyth test
      // const vaa = await fetchOffchainPrice(btcUsdId)
      console.log(await pythOracleProvider.currentVersion())
      // await (await pythOracleProvider.updatePrice(vaa)).wait()
      // console.log(await pythOracleProvider.currentVersion())
    })
  })
}

async function fetchOffchainPrice(feedId: string, publishTimeReq?: number) {
  try {
    // https://hermes.pyth.network/docs/#/
    let url = `https://hermes.pyth.network/api/latest_price_feeds?binary=true&ids[]=${feedId}`
    if (publishTimeReq) {
      url = `${url}&publish_time=${publishTimeReq}`
    }

    const res = await fetch(url)
    const result = await res.json()

    return '0x' + Buffer.from(result[0].vaa, 'base64').toString('hex')
  } catch (e) {
    throw e
  }
}
