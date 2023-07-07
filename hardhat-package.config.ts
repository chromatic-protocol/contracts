export default {
  includes: [
    '**/IOracleProvider.sol/**',
    '**/IOracleProviderRegistry.sol/**',
    '**/ChromaticMarket.sol/**',
    '**/ChromaticMarketFactory.sol/**',
    '**/ChromaticVault.sol/**',
    '**/ChromaticAccount.sol/**',
    '**/ChromaticRouter.sol/**',
    '**/CLBToken.sol/**',
    '**/ChromaticLens.sol/**',
    '**/AggregatorV3Interface.sol/**',
    '**/IERC20.sol/*',
    '**/IERC20Metadata.sol/*',
    '**/IERC1155.sol/*'
  ],
  excludes: ['**/*Lib', '**/*Mock', '**.dbg.json', 'build-info/**'],
  includeDeployed: true,
  artifactFromDeployment: true,
  includesFromDeployed: [
    'ChromaticLens',
    'ChromaticLiquidator',
    'ChromaticMarketFactory',
    'ChromaticRouter',
    'ChromaticVault'
  ],
  // excludesFromDeployed: ['KeeperFeePayer', '*Lib', '*Mock', 'ChainlinkFeedOracle'],
  excludeBytecode: true
}
