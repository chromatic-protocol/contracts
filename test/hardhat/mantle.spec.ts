/*
import { setChain } from './utils'
import { prepareMarketTest } from './market/testHelper'
import * as helpers from '@nomicfoundation/hardhat-network-helpers'
import { agniTest } from './swap/agni.spec'
describe('[mantle]', async () => {
  let initChainSnapshot: helpers.SnapshotRestorer
  let deps: any
  const targetNetwork = 'mantle_testnet'
  before(async () => {
    await setChain(targetNetwork)
    deps = await prepareMarketTest('mantle')
    initChainSnapshot = await helpers.takeSnapshot()
  })

  beforeEach(async () => {
    await initChainSnapshot.restore()
  })

  const { feeSpec, lensSpec, liquidationSpec, liuqiditySpec, tradeSpec } = require('./market/specs')
  const { supraSpec, pythSpec } = require('./oracle_provider/specs')

  const getDeps = () => deps
  feeSpec(getDeps)
  lensSpec(getDeps)
  liquidationSpec(getDeps)
  liuqiditySpec(getDeps)
  tradeSpec(getDeps)
  supraSpec(targetNetwork)
  pythSpec(targetNetwork)
  agniTest()
})
*/