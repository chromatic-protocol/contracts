import { PythErrors__factory, PythFeedOracle } from '@chromatic/typechain-types'
import { ethers } from 'hardhat'
import { forkingOptions } from '../../utils'
import { evmMainnet, evmTestnet } from '../pythFeedIds'
import { expect } from 'chai'
import { Interface } from 'ethers'
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'

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
    let signer: HardhatEthersSigner

    beforeEach(async () => {
      pythAddress = IPYTH_ADDRESSES[networkName]
      btcUsdId = priceFeedIdsMap[networkName]['Crypto.BTC/USD']
      ;[signer] = await ethers.getSigners()
      const pythFeedOracleF = await ethers.getContractFactory('PythFeedOracle', signer)
      pythOracleProvider = await pythFeedOracleF.deploy(pythAddress, btcUsdId, 'BTC/USD')
    })

    it('updatePrice and sync', async () => {
      const ts = (await timestamp()) - 1
      const offchainPrice = await fetchOffchainPrice(btcUsdId, ts)

      const fee = await pythOracleProvider.getUpdateFee(offchainPrice.extraData)
      const beforeVersion = await pythOracleProvider.lastSyncedVersion()

      await (await pythOracleProvider.updatePrice(offchainPrice.extraData, { value: fee })).wait()
      const versionAfterUpdate = await pythOracleProvider.lastSyncedVersion()
      expect(beforeVersion).to.deep.equal(versionAfterUpdate)

      await (await pythOracleProvider.sync()).wait()
      const versionAfterSync = await pythOracleProvider.lastSyncedVersion()
      expect(beforeVersion.version).lessThan(versionAfterSync.version)
      expect(beforeVersion.timestamp).lessThan(versionAfterSync.timestamp)
      expect(BigInt(offchainPrice.publishTime)).equal(versionAfterSync.timestamp)
      // expect(BigInt(offchainPrice.price)).equal(versionAfterSync.price) // decimal diff
    })

    it('revert test', async () => {
      const ts = (await timestamp()) - 1
      const offchainPrice = await fetchOffchainPrice(btcUsdId, ts)

      const iface = new Interface(PythErrors__factory.abi)

      await expect(pythOracleProvider.updatePrice(offchainPrice.extraData)).revertedWithCustomError(
        { interface: iface },
        'InsufficientFee'
      )

      await expect(pythOracleProvider.updatePrice('0xDD')).revertedWithoutReason()
    })

    it('refund test', async () => {
      const ts = (await timestamp()) - 1
      const offchainPrice = await fetchOffchainPrice(btcUsdId, ts)

      const fee = await pythOracleProvider.getUpdateFee(offchainPrice.extraData)

      await expect(
        pythOracleProvider.updatePrice(offchainPrice.extraData, { value: fee })
      ).changeEtherBalance(await signer.getAddress(), -fee)

      await expect(
        pythOracleProvider.updatePrice(offchainPrice.extraData, { value: fee })
      ).changeEtherBalance(await signer.getAddress(), 0)
    })

    it('emit event', async () => {
      const ts = (await timestamp()) - 1
      const offchainPrice = await fetchOffchainPrice(btcUsdId, ts)

      const fee = await pythOracleProvider.getUpdateFee(offchainPrice.extraData)

      const pyth = await ethers.getContractAt('IPyth', await pythOracleProvider.pyth())

      await expect(pythOracleProvider.updatePrice(offchainPrice.extraData, { value: fee })).emit(
        pyth,
        'PriceFeedUpdate'
      )

      // PriceFeedUpdate
    })

    it('pyth onchain update test', async () => {
      const ts = (await timestamp()) - 1
      const offchainPrice = await fetchOffchainPrice(btcUsdId, ts)

      const fee = await pythOracleProvider.getUpdateFee(offchainPrice.extraData)

      const pyth = await ethers.getContractAt('IPyth', await pythOracleProvider.pyth())

      const priceBeforeUpdate = await pyth.getPriceUnsafe(btcUsdId)

      // prettier-ignore
      await (await pyth.parsePriceFeedUpdates([(await fetchOffchainPrice(btcUsdId, ts - 10)).vaa], [btcUsdId], 0, ts + 100, { value: fee })).wait()
      const priceAfterParsePriceFeedUpdates = await pyth.getPriceUnsafe(btcUsdId)
      expect(priceBeforeUpdate).to.deep.equal(priceAfterParsePriceFeedUpdates)

      // prettier-ignore
      await (await pyth.updatePriceFeeds([(await fetchOffchainPrice(btcUsdId, ts - 8)).vaa], { value: fee })).wait()
      const priceAfterUpdatePriceFeeds = await pyth.getPriceUnsafe(btcUsdId)
      expect(priceAfterUpdatePriceFeeds.publishTime).greaterThan(priceBeforeUpdate.publishTime)
      expect(priceAfterUpdatePriceFeeds.publishTime).equal(ts - 8)

      // prettier-ignore
      await (await pyth.updatePriceFeeds([(await fetchOffchainPrice(btcUsdId, ts - 10)).vaa], { value: fee })).wait()
      expect(await pyth.getPriceUnsafe(btcUsdId)).to.deep.equal(priceAfterUpdatePriceFeeds)
    })

    async function timestamp() {
      return (await ethers.provider.getBlock('latest'))!.timestamp
    }
  })
}

async function fetchOffchainPrice(feedId: string, publishTimeReq?: number) {
  try {
    // https://hermes.pyth.network/docs/#/
    let url = `https://hermes.pyth.network/api/get_price_feed?binary=true&id=${feedId}`
    if (publishTimeReq) {
      url = `${url}&publish_time=${publishTimeReq}`
    }
    // console.log(url)

    const res = await fetch(url)
    const result = await res.json()
    const price = result.price

    const vaa = '0x' + Buffer.from(result.vaa, 'base64').toString('hex')

    return {
      id: feedId,
      conf: price.conf,
      price: price.price,
      expo: price.expo,
      publishTime: price.publish_time,
      vaa: vaa,
      extraData: ethers.AbiCoder.defaultAbiCoder().encode(
        ['tuple(uint256, int64, int32, bytes)'],
        [[price.publish_time, price.price, price.expo, vaa]]
      )
    }
  } catch (e) {
    throw e
  }
}
