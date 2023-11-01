export default {
  includes: [
    '**/IOracleProvider.sol/**',
    '**/IOracleProviderRegistry.sol/**',
    '**/IChromaticMarket.sol/**',
    '**/ChromaticMarketFactory.sol/**',
    '**/ChromaticVault.sol/**',
    '**/ChromaticAccount.sol/**',
    '**/ChromaticRouter.sol/**',
    '**/CLBToken.sol/**',
    '**/ChromaticLens.sol/**',
    '**/AggregatorV3Interface.sol/**',
    '**/IERC20.sol/*',
    '**/IERC20Metadata.sol/*',
    '**/IERC1155.sol/*',
    '**/facets/market/*.sol/*',
    '**/mocks/TestSettlementToken.sol/**'
  ],
  excludes: ['**/*Lib', '**/*Mock', '**.dbg.json', 'build-info/**'],
  includeDeployed: true,
  artifactFromDeployment: true,
  includesFromDeployed: [
    'ChromaticLens',
    'ChromaticMarketFactory',
    'ChromaticRouter',
    'ChromaticVault',
    'cETH',
    'cBTC'
  ],
  excludesFromDeployed: ['*Mock'],
  excludeBytecode: true
}
