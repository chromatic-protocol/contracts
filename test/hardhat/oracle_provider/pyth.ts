import { IPyth__factory, IPyth } from '@chromatic/typechain-types'
import { ethers } from 'hardhat'
import { evmMainnet, evmTestnet } from './pythFeedIds'


const IPYTH_ADDRESSES: { [key: string]: string } = {
  arbitrum_one: '0xff1a0f4744e8582DF1aE09D5611b887B6a12925C',
  arbitrum_goerli: '0x939C0e902FF5B3F7BA666Cc8F6aC75EE76d3f900',
  mantle: '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729',
  mantle_goerli: '0xA2aa501b19aff244D90cc15a4Cf739D2725B5729'
}

const priceFeedAddresses: { [key: string]: { [key: string]: string } } = {
  arbitrum_one: evmMainnet,
  arbitrum_goerli: evmTestnet,
  mantle: evmMainnet,
  mantle_goerli: evmTestnet
}

describe('pyth test', async function () {
  var ipyth: IPyth
  var priceFeedIds: { [key: string]: string }
  before(async () => {
    const [signer] = await ethers.getSigners()
    const networkName = (signer.provider as any)['_networkName']
    if (IPYTH_ADDRESSES[networkName]) {
      console.log(networkName, IPYTH_ADDRESSES[networkName])
      ipyth = IPyth__factory.connect(IPYTH_ADDRESSES[networkName], signer)
      priceFeedIds = priceFeedAddresses[networkName]
    }
  })

  it('price feed id check', async () => {
    // no backends available for method (Mantle)
    // const events = await ipyth.queryFilter(
    //   ipyth.filters['PriceFeedUpdate(bytes32,uint64,int64,uint64)']()
    // )

    // 9.4~
    const fromEvents = [
      '0x03ae4db29ed4ae33d323568895aa00337e658e348b37509f5372ae51f0af00d5',
      '0x15add95022ae13563a11992e727c91bdb6b55bc183d9d747436c80a483d8c864',
      '0x15ecddd26d49e1a8f1de9376ebebc03916ede873447c1255d2d5891b92ce5717',
      '0x19e09bb805456ada3979a7d1cbb4b6d63babc3a0f8e8a9509f68afa5c4c11cd5',
      '0x23199c2bcb1303f667e733b9934db9eca5991e765b45f5ed18bc4b231415f2fe',
      '0x23d7315113f5b1d3ba7a83604c44b94d79f4fd69af77f804fc7f920a6dc65744',
      '0x2a01deaec9e51a579277b34b122399984d0bbf57e2458a7e42fecd2829867a0d',
      '0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b',
      '0x2b9ab1e972a281585084148ba1389800799bd4be63b957507db1349314e47445',
      '0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f',
      '0x3dd2b63686a450ec7290df3a1e0b583c0481f651351edfa7636f39aed55cf8a3',
      '0x3fa4252848f9f0a1480be62745a4629d9eb1322aebab8a791e344b3b9c1adcf5',
      '0x46b8cc9347f04391764a0361e0b17c3ba394b001e7c304f7650f6376e37c321d',
      '0x4e3037c822d852d79af3ac80e35eb420ee3b870dca49f9344a38ef4773fb0585',
      '0x67a6f93030420c1c9e3fe37c1ab6b77966af82f995944a9fefce357a22854a80',
      '0x67aed5a24fdad045475e7195c98a98aea119c763f272d4523f5bac93a4f33c2b',
      '0x6e3f3fa8253588df9326580180233eb791e03b443a3ba7a1d892e73874e19a54',
      '0x70dddcb074263ce201ea9a1be5b3537e59ed5b9060d309e12d61762cfe59fb7e',
      '0x78d185a741d07edb3412b09008b7c5cfb9bbbd7d568bf00ba737b456ba171501',
      '0x7a5bc1d2b56ad029048cd63964b3ad2776eadf812edc1a43a31406cb54bff592',
      '0x7f981f906d7cfe93f618804f1de89e0199ead306edc022d3230b3e8305f391b0',
      '0x846ae1bdb6300b817cee5fdee2a6da192775030db5615b94a465f53bd40850b5',
      '0x8ac0c70fff57e9aefdf5edf44b51d62c2d433653cbb2cf5cc06bb115af04d221',
      '0x9695e2b96ea7b3859da9ed25b7a46a920a776e2fdae19a7bcfdf2b219230452d',
      '0xa19d04ac696c7a6616d291c7e5d1377cc8be437c327b75adb5dc1bad745fcae8',
      '0xa995d00bb36a63cef7fd2c287dc105fc8f3d93779f062f09551b0af3e81ec30b',
      '0xb962539d0fcb272a494d65ea56f94851c2bcf8823935da05bd628916e2e9edbf',
      '0xc19405e4c8bdcbf2a66c37ae05a27d385c8309e9d648ed20dc6ee717e7d30e17',
      '0xc5f60d00d926ee369ded32a38a6bd5c1e0faa936f91b987a5d0dcf3c5d8afab0',
      '0xc63e2a7f37a04e5e614c07238bedb25dcc38927fba8fe890597a593c0b2fa4ad',
      '0xc7b72e5d860034288c9335d4d325da4272fe50c92ab72249d58f6cbba30e4c44',
      '0xc8acad81438490d4ebcac23b3e93f31cdbcb893fcba746ea1c66b89684faae2f',
      '0xca3eed9b267293f6595901c734c7525ce8ef49adafe8284606ceb307afa2ca5b',
      '0xdcef50dd0a4cd2dcc17e45df1676dcb336a11a61c69df7a0299b0150c672d25c',
      '0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43',
      '0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a',
      '0xec5d399846a9209f3fe5881d70aae9268c94339ff9817e8d18ff19fa05eea1c8',
      '0xef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d',
      '0xf0d57deca57b3da2fe63a493f4c25925fdfd8edf834b20f93e1f84dbd1504d4a',
      '0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace'
    ]

    fromEvents.forEach((addr) => {
      const index = Object.values(priceFeedIds).indexOf(addr)
      console.log(Object.keys(priceFeedIds)[index], addr)
    })

    // Crypto.MNT/USD
    console.log(
      await ipyth.getPriceUnsafe(
        '0x4e3037c822d852d79af3ac80e35eb420ee3b870dca49f9344a38ef4773fb0585'
      )
    )

    // Crypto.GNO/USD
    console.log(
      await ipyth.getPriceUnsafe(
        '0xc5f60d00d926ee369ded32a38a6bd5c1e0faa936f91b987a5d0dcf3c5d8afab0'
      )
    )
    // Crypto.STETH/USD
    console.log(
      await ipyth.getPriceUnsafe(
        '0x846ae1bdb6300b817cee5fdee2a6da192775030db5615b94a465f53bd40850b5'
      )
    )

    // Crypto.ETH.USD
    console.log(
      await ipyth.getPriceUnsafe(
        '0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace'
      )
    )
    
    const txs = Object.keys(priceFeedIds).map((k) => ipyth.priceFeedExists(priceFeedIds[k]))
    const results = await Promise.all(txs)
    console.log(results.filter((e) => e === true).length)
  })
})
