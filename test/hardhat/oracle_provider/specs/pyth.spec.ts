import {
  AbstractPyth,
  AbstractPyth__factory,
  PythErrors__factory
} from '@chromatic/typechain-types'
import { expect } from 'chai'
import { ethers } from 'hardhat'
import { forkingOptions } from '../../utils'
import { evmMainnet, evmTestnet } from '../pythFeedIds'

const IPYTH_ADDRESSES: { [key: string]: string } = {
  arbitrum_one: '0xff1a0f4744e8582DF1aE09D5611b887B6a12925C',
  arbitrum_sepolia: '0x4374e5a8b9C22271E9EB878A2AA31DE97DF15DAF',
  mantle: '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729',
  mantle_testnet: '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729',
}

const priceFeedIdsMap: { [key: string]: { [key: string]: string } } = {
  arbitrum_one: evmMainnet,
  arbitrum_sepolia: evmTestnet,
  mantle: evmMainnet,
  mantle_testnet: evmTestnet
}

export function spec(networkName: keyof typeof forkingOptions) {
  describe('pyth test', async function () {
    var pyth: AbstractPyth
    var pythAddress: string
    var priceFeedIds: { [key: string]: string }
    before(async () => {
      const [signer] = await ethers.getSigners()
      pythAddress = IPYTH_ADDRESSES[networkName]
      console.log(networkName, pythAddress)
      pyth = AbstractPyth__factory.connect(pythAddress, signer)
      priceFeedIds = priceFeedIdsMap[networkName]
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

    it('PythOracleProvider deploy valid price feed id & decimal test', async () => {
      await expect(pyth.getPriceUnsafe(`0x${'77'.repeat(32)}`)).revertedWithCustomError(
        PythErrors__factory.connect(pythAddress),
        'PriceFeedNotFound'
      ) // 0x14aebe68

      const priceFeedExists = await Promise.all(
        Object.values(priceFeedIds).map((id) => pyth.priceFeedExists(id))
      )

      const existIds: string[] = []
      const descriptions: string[] = []

      for (let i = 0; i < priceFeedExists.length; i++) {
        if (priceFeedExists[i]) {
          existIds.push(Object.values(priceFeedIds)[i])
          descriptions.push(Object.keys(priceFeedIds)[i])
        }
      }

      const prices = await Promise.all(existIds.map((id) => pyth.getPriceUnsafe(id)))

      console.log('Exist price count', existIds.length)

      const pythFeedOracleF = await ethers.getContractFactory('PythFeedOracle')

      const pythFeedOracles = await Promise.all(
        Array.from({ length: existIds.length }, (_, i) => i).map((i) =>
          pythFeedOracleF.deploy(pythAddress, existIds[i], descriptions[i])
        )
      )

      console.log('deployed PythFeedOracle count :', pythFeedOracles.length)

      const currentVersions = await Promise.all(
        pythFeedOracles.map((oracle) => oracle.currentVersion())
      )

      const originPrices = prices.map((p) => p.price * 10n ** (18n + p.expo))
      const oraclePrices = currentVersions.map((v) => v.price)
      expect(originPrices).to.deep.equal(oraclePrices)
    })
  })
}
