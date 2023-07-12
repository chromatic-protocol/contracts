import type { HardhatUserConfig } from 'hardhat/config'
import config from './hardhat.config'
import docgenConfig from './docs/docgen.errors.config'

const docsConfig: HardhatUserConfig = {
  ...config,
  docgen: docgenConfig
}

export default docsConfig
