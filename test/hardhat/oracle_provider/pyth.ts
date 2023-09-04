import { expect } from 'chai'
import { IPyth__factory, IPyth } from '@chromatic/typechain-types'
import { ethers } from 'hardhat'
import { mantleGoerli, mantleMainnet } from './pythFeedIds'

const IPYTH_ADDRESSES: { [key: string]: string } = {
  mantle: '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729',
  mantle_goerli: '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729'
}

const priceFeedAddresses: { [key: string]: { [key: string]: string } } = {
  mantle: mantleMainnet,
  mantle_goerli: mantleGoerli
}

describe('pyth test', async function () {
  var ipyth: IPyth
  var priceFeedIds: { [key: string]: string }
  before(async () => {
    const [signer] = await ethers.getSigners()
    const networkName = (signer.provider as any)['_networkName']
    if (IPYTH_ADDRESSES[networkName]) {
      ipyth = IPyth__factory.connect(IPYTH_ADDRESSES[networkName], signer)
      priceFeedIds = priceFeedAddresses[networkName]
    }
  })

  it('price feed id check', async () => {
    const txs = Object.keys(priceFeedIds).map(k => ipyth.priceFeedExists(priceFeedIds[k]))
    const results = await Promise.all(txs)
    console.log(results.filter(e=>e === true).length)
  
    
  })
})
