import type { HardhatUserConfig } from 'hardhat/config'
import config from './hardhat.config'

const defaultDocsConfig: HardhatUserConfig = {
  ...config,
  solidity: {
    compilers: [
      {
        version: '0.8.20', // for struct and enum
        settings: {
          optimizer: {
            enabled: true,
            runs: 30000
          }
        }
      }
    ]
  },
}

export default defaultDocsConfig
