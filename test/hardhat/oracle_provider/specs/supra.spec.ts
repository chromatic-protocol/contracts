import { ISupraSValueFeed, ISupraSValueFeed__factory } from '@chromatic/typechain-types'
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { expect } from 'chai'
import { ethers } from 'hardhat'
import { forkingOptions, parseSupraPriace } from '../../utils'

const SUPRA_ADDRESSES: { [key: string]: string } = {
  arbitrum_one: '0x8a358F391d93f7558D5F5E61BDf533e2cc3Cf7a3',
  arbitrum_goerli: '0xFfFB8022d4cB9B42762f38f116F955776d9D2a34',
  mantle_testnet: '0x4Ce261C19af540f1175CdeB9E3490DC8937D78e5',
  anvil: '0x4Ce261C19af540f1175CdeB9E3490DC8937D78e5'
}

export function spec(networkName: keyof typeof forkingOptions) {
  describe('supra test', async function () {
    var isupra: ISupraSValueFeed
    var supraAddress: string
    var signer: HardhatEthersSigner
    before(async () => {
      console.log(networkName)
      const signers = await ethers.getSigners()
      signer = signers[0]
      supraAddress = SUPRA_ADDRESSES[networkName]
      console.log(networkName, supraAddress)
      isupra = ISupraSValueFeed__factory.connect(SUPRA_ADDRESSES[networkName], signer)
    })

    it('data parsing test', async () => {
      const [data] = await isupra.getSvalue(pairIndex['eth_usd'])
      const supraPrice = parseSupraPriace(data)
      console.log(supraPrice)
      expect(supraPrice.decimal).equal(8n)
    })

    it('feed exist test', async () => {
      const [data] = await isupra.getSvalue(pairIndex['eth_usd'])
      const supraPrice = parseSupraPriace(data)
      console.log(supraPrice)
      const results = await isupra.getSvalues(Object.values(pairIndex))
      const datas = results[0]
      const flags = results[1]
      for (let i = 0; i < datas.length; i++) {
        const data = datas[i]
        const hasPrice = !flags[i]
        let infoString = ''
        if (hasPrice) {
          const supraPrice = parseSupraPriace(data)
          infoString = `decimals: ${supraPrice.price}, price: ${
            supraPrice.price
          } timestamp: ${new Date(Number(supraPrice.timestamp))}`
        }
        console.log(`${Object.keys(pairIndex)[i]} has feed : ${hasPrice} ${infoString}`)
      }

      expect(datas.map((e) => e == `0x${'00'.repeat(32)}`)).to.deep.equal(flags)
    })
  })
}

const pairIndex: { [key: string]: string } = {
  btc_usdt: '0',
  eth_usdt: '1',
  doge_usdt: '3',
  bch_usdt: '4',
  avax_usdt: '5',
  dot_usdt: '6',
  aave_usdt: '7',
  uni_usdt: '8',
  ltc_usdt: '9',
  sol_usdt: '10',
  mkr_usdt: '11',
  comp_usdt: '12',
  sushi_usdt: '13',
  xrp_usdt: '14',
  trx_usdt: '15',
  ada_usdt: '16',
  atom_usdt: '17',
  btc_usd: '18',
  eth_usd: '19',
  matic_usdt: '20',
  bat_usdt: '21',
  snx_usdt: '22',
  yfi_usdt: '23',
  fil_usdt: '24',
  eos_usdt: '25',
  etc_usdt: '26',
  bch_usd: '27',
  matic_usd: '28',
  algo_usdt: '29',
  ont_usdt: '30',
  link_usd: '31',
  aave_usd: '32',
  uni_usd: '33',
  sushi_usd: '34',
  crv_usdt: '35',
  enj_usdt: '36',
  mana_usdt: '37',
  xtz_usdt: '38',
  omg_usdt: '39',
  ren_usdt: '40',
  dai_usdt: '41',
  xlm_usdt: '42',
  rsr_usdt: '43',
  neo_usdt: '44',
  btc_usdc: '45',
  eth_usdc: '46',
  usdc_usdt: '47',
  usdt_usd: '48',
  bnb_usdt: '49',
  comp_usd: '50',
  enj_usd: '51',
  zrx_usdt: '52',
  lrc_usdt: '53',
  dai_usd: '54',
  knc_usdt: '55',
  ftm_usdt: '56',
  bal_usdt: '57',
  band_usdt: '58',
  dash_usdt: '59',
  zec_usdt: '60',
  rune_usdt: '61',
  vet_usdt: '62',
  avax_usd: '63',
  ltc_usd: '64',
  sol_usd: '65',
  dot_usd: '66',
  mkr_usd: '67',
  bat_usd: '68',
  doge_usd: '69',
  xrp_usd: '70',
  yfi_usd: '71',
  zrx_usd: '72',
  oxt_usdt: '73',
  uma_usdt: '74',
  hbar_usdt: '75',
  srm_usdt: '76',
  sxp_usdt: '77',
  ksm_usdt: '78',
  c98_usdt: '79',
  arb_usdt: '80',
  arb_usd: '81',
  fx_eth: '82',
  fx_usdt: '83',
  fx_btc: '84',
  pundix_usdt: '85',
  pundix_eth: '86',
  pundix_btc: '87',
  fuse_usdt: '88',
  usdc_usd: '89',
  sui_usdt: '90',
  stg_usdt: '91',
  pepe_usdt: '92',
  cetus_usdt: '93',
  sys_usdt: '94',
  weth_ush: '95',
  svusd_usdc: '96',
  svbtc_wbtc: '97',
  sveth_weth: '98',
  unsheth_ush: '99',
  svy_weth: '100'
}
