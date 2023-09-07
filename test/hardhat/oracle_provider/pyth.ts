import { AbstractPyth, AbstractPyth__factory } from '@chromatic/typechain-types'
import { ethers } from 'hardhat'
import { evmMainnet, evmTestnet } from './pythFeedIds'
import { expect } from 'chai'

const IPYTH_ADDRESSES: { [key: string]: string } = {
  arbitrum_one: '0xff1a0f4744e8582DF1aE09D5611b887B6a12925C',
  arbitrum_goerli: '0x939C0e902FF5B3F7BA666Cc8F6aC75EE76d3f900',
  mantle: '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729',
  mantle_testnet: '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729'
}

const priceFeedIdsMap: { [key: string]: { [key: string]: string } } = {
  arbitrum_one: evmMainnet,
  arbitrum_goerli: evmTestnet,
  mantle: evmMainnet,
  mantle_testnet: evmTestnet
}

describe('pyth test', async function () {
  var ipyth: AbstractPyth
  var priceFeedIds: { [key: string]: string }
  before(async () => {
    const [signer] = await ethers.getSigners()
    const networkName = (signer.provider as any)['_networkName']
    if (IPYTH_ADDRESSES[networkName]) {
      console.log(networkName, IPYTH_ADDRESSES[networkName])
      ipyth = AbstractPyth__factory.connect(IPYTH_ADDRESSES[networkName], signer)
      priceFeedIds = priceFeedIdsMap[networkName]
    }
  })

  it('price feed id check', async () => {
    // no backends available for method (Mantle)
    // const events = await ipyth.queryFilter(
    //   ipyth.filters['PriceFeedUpdate(bytes32,uint64,int64,uint64)']()
    // )

    const ethUsdId = priceFeedIds['Crypto.ETH/USD']
    const wrongId = `0x${'FF'.repeat(32)}`

    expect(await ipyth.priceFeedExists(ethUsdId)).equal(true)
    expect(await ipyth.priceFeedExists(wrongId)).equal(false)
    console.log(await ipyth.getPriceUnsafe(ethUsdId))

    expect(await ipyth.getPriceUnsafe(ethUsdId)).not.revertedWith('')
  })
})
