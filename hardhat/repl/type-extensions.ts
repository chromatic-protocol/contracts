// If your plugin extends types from another plugin, you should import the plugin here.

// To extend one of Hardhat's types, you need to import the module where it has been defined, and redeclare it.
import 'hardhat/types/runtime'
import 'hardhat-deploy'
import { BigNumber } from 'ethers'
import { IOracleProvider } from '../../typechain-types'

declare module 'hardhat/types/runtime' {
  interface HardhatRuntimeEnvironment {
    w: object
    initialize?: () => Promise<void>
    updatePrice?: (number) => Promise<void>
    currentOracleVersion?: () => Promise<IOracleProvider.OracleVersionStructOutput>
  }
}
