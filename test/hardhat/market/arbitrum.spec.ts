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
  const { test: feeTest } = require('./fee.spec')
  const { test: lensTest } = require('./lens.spec')
  const { test: liquidationTest } = require('./liquidation.spec')
  const { test: liuqidityTest } = require('./liquidity.spec')
  const getDeps = () => deps
  feeTest(getDeps)
  lensTest(getDeps)
  liquidationTest(getDeps)
  liuqidityTest(getDeps)
})
