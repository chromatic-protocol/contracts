import type { HardhatUserConfig } from 'hardhat/config'

export default {
  pages: 'files',
  templates: 'docs/templates',
  exclude: ['mocks'],
  outputDir: 'docs/out'
} as HardhatUserConfig['docgen']
