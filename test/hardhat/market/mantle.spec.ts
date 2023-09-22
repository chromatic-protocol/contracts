import { setChain } from '../utils'
import { prepareMarketTest } from './testHelper'
import * as helpers from '@nomicfoundation/hardhat-network-helpers'
describe('[mantle]', async () => {
  let initChainSnapshot: helpers.SnapshotRestorer
  let deps: any
  before(async () => {
    console.log('set chain')
    await setChain('mantle_testnet')
    deps = await prepareMarketTest('mantle')
    initChainSnapshot = await helpers.takeSnapshot()
  })

  beforeEach(async () => {
    await initChainSnapshot.restore()
  })

  const { feeSpec, lensSpec, liquidationSpec, liuqiditySpec, tradeSpec } = require('./specs')

  const getDeps = () => deps
  feeSpec(getDeps)
  lensSpec(getDeps)
  liquidationSpec(getDeps)
  liuqiditySpec(getDeps)
  tradeSpec(getDeps)
})
