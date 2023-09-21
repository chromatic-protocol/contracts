import { prepareMarketTest } from './testHelper'

describe('[arbitrum]', async () => {
  const { test: feeTest } = require('./fee.spec')
  const { test: lensTest } = require('./lens.spec')
  const { test: liquidationTest } = require('./liquidation.spec')
  const { test: liuqidityTest } = require('./liquidity.spec')
  const prepareMarketFn = () => prepareMarketTest('arbitrum')
  feeTest(prepareMarketFn)
  lensTest(prepareMarketFn)
  liquidationTest(prepareMarketFn)
  liuqidityTest(prepareMarketFn)
})
