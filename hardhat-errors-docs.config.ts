import type { HardhatUserConfig } from 'hardhat/config'
import docgenConfig from './docs/docgen.errors.config'
import config from './hardhat.config'

const docsConfig: HardhatUserConfig = {
  ...config,
  solidity: {
    compilers: [
      {
        version: '0.8.20' // for struct and enum
      }
    ]
  },
  docgen: docgenConfig
}

export default docsConfig
