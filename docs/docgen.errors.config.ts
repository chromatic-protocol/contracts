import type { HardhatUserConfig } from 'hardhat/config'

export default {
  pages: 'single',
  templates: 'docs/errors-templates',
  exclude: ['mocks'],
  outputDir: 'docs/out/errors'
} as HardhatUserConfig['docgen']
