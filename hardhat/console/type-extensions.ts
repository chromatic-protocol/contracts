// If your plugin extends types from another plugin, you should import the plugin here.

// To extend one of Hardhat's types, you need to import the module where it has been defined, and redeclare it.
import 'hardhat-deploy'
import 'hardhat/types/runtime'
import {
  ChromaticLens,
  ChromaticLiquidator,
  ChromaticMarketFactory,
  ChromaticRouter,
  ChromaticVault,
  KeeperFeePayer
} from '../../typechain-types'

declare module 'hardhat/types/runtime' {
  interface HardhatRuntimeEnvironment {
    c: {
      factory: ChromaticMarketFactory | undefined
      vault: ChromaticVault | undefined
      liquidator: ChromaticLiquidator | undefined
      router: ChromaticRouter | undefined
      lens: ChromaticLens | undefined
      keeperFeePayer: KeeperFeePayer | undefined
    }
    initialize?: () => Promise<void>
  }
}
