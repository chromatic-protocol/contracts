// If your plugin extends types from another plugin, you should import the plugin here.

// To extend one of Hardhat's types, you need to import the module where it has been defined, and redeclare it.
import { IOracleProvider } from '@chromatic/typechain-types'
import 'hardhat-deploy'
import 'hardhat/types/runtime'

declare module 'hardhat/types/runtime' {
  interface HardhatRuntimeEnvironment {
    w: { [accountName: string]: any }
    initialize?: () => Promise<void>
    updatePrice?: (price: number) => Promise<void>
    currentOracleVersion?: () => Promise<IOracleProvider.OracleVersionStructOutput>
    showMeTheMoney?: (account: string, ethAmount: number, usdcAmount: number) => Promise<void>
  }
}
