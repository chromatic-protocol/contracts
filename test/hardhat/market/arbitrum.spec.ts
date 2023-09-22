import { setChain } from '../utils'
import { prepareMarketTest } from './testHelper'
import * as helpers from '@nomicfoundation/hardhat-network-helpers'
describe('[arbitrum]', async () => {
  let initChainSnapshot: helpers.SnapshotRestorer
  let deps: any
  before(async () => {
    console.log('set chain')
    await setChain('arbitrum_goerli')
    deps = await prepareMarketTest('arbitrum')
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
