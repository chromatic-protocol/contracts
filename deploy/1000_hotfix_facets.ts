import chalk from 'chalk'
import { ContractRunner, FunctionFragment, ZeroAddress, ZeroHash } from 'ethers'
import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import {
  ChromaticMarketFactory__factory,
  IDiamondCut,
  IDiamondCut__factory,
  IDiamondLoupe__factory
} from '../typechain-types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { config, deployments, getNamedAccounts, ethers, network } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()
  const deployOpts = { from: deployer }

  const { address: marketStateFacet } = await deploy('MarketStateFacet', deployOpts)
  console.log(chalk.yellow(`✨ MarketStateFacet: ${marketStateFacet}`))

  const { address: marketAddLiquidityFacet } = await deploy('MarketAddLiquidityFacet', deployOpts)
  console.log(chalk.yellow(`✨ MarketAddLiquidityFacet: ${marketAddLiquidityFacet}`))

  const { address: marketRemoveLiquidityFacet } = await deploy(
    'MarketRemoveLiquidityFacet',
    deployOpts
  )
  console.log(chalk.yellow(`✨ MarketRemoveLiquidityFacet: ${marketRemoveLiquidityFacet}`))

  const { address: marketLensFacet } = await deploy('MarketLensFacet', deployOpts)
  console.log(chalk.yellow(`✨ MarketLensFacet: ${marketLensFacet}`))

  const { address: marketTradeOpenPositionFacet } = await deploy(
    'MarketTradeOpenPositionFacet',
    deployOpts
  )
  console.log(chalk.yellow(`✨ MarketTradeOpenPositionFacet: ${marketTradeOpenPositionFacet}`))

  const { address: marketTradeClosePositionFacet } = await deploy(
    'MarketTradeClosePositionFacet',
    deployOpts
  )
  console.log(chalk.yellow(`✨ MarketTradeClosePositionFacet: ${marketTradeClosePositionFacet}`))

  const { address: marketLiquidateFacet } = await deploy('MarketLiquidateFacet', deployOpts)
  console.log(chalk.yellow(`✨ MarketLiquidateFacet: ${marketLiquidateFacet}`))

  const { address: marketSettleFacet } = await deploy('MarketSettleFacet', deployOpts)
  console.log(chalk.yellow(`✨ MarketSettleFacet: ${marketSettleFacet}`))

  const runner = await ethers.getSigner(deployer)
  const factory = await deployments.get('ChromaticMarketFactory')
  const marketFactory = ChromaticMarketFactory__factory.connect(factory.address, runner)
  const markets = await marketFactory.getMarkets()
  for (const market of markets) {
    await updateFacet(
      market,
      {
        marketStateFacet,
        marketAddLiquidityFacet,
        marketRemoveLiquidityFacet,
        marketLensFacet,
        marketTradeOpenPositionFacet,
        marketTradeClosePositionFacet,
        marketLiquidateFacet,
        marketSettleFacet
      },
      runner
    )
  }
}

const SELECTOR_FOR_STATE_FACET = FunctionFragment.getSelector('factory')
const SELECTOR_FOR_ADD_LIQUIDITY_FACET = FunctionFragment.getSelector('addLiquidity', [
  'address',
  'int16',
  'bytes'
])
const SELECTOR_FOR_REMOVE_LIQUIDITY_FACET = FunctionFragment.getSelector('removeLiquidity', [
  'address',
  'int16',
  'bytes'
])
const SELECTOR_FOR_LENS_FACET = FunctionFragment.getSelector('getBinLiquidity', ['int16'])
const SELECTOR_FOR_OPEN_POSITION_FACET = FunctionFragment.getSelector('openPosition', [
  'int256',
  'uint256',
  'uint256',
  'uint256',
  'bytes'
])
const SELECTOR_FOR_CLOSE_POSITION_FACET = FunctionFragment.getSelector('closePosition', ['uint256'])
const SELECTOR_FOR_LIQUIDATE_FACET = FunctionFragment.getSelector('checkLiquidation', ['uint256'])
const SELECTOR_FOR_SETTLE_FACET = FunctionFragment.getSelector('settleAll')

type Facets = {
  marketStateFacet: string
  marketAddLiquidityFacet: string
  marketRemoveLiquidityFacet: string
  marketLensFacet: string
  marketTradeOpenPositionFacet: string
  marketTradeClosePositionFacet: string
  marketLiquidateFacet: string
  marketSettleFacet: string
}

async function updateFacet(marketAddress: string, newFacets: Facets, runner: ContractRunner) {
  console.log(`Update ${marketAddress}`)

  const loupe = IDiamondLoupe__factory.connect(marketAddress, runner)
  const oldFacets: Facets = {
    marketStateFacet: await loupe.facetAddress(SELECTOR_FOR_STATE_FACET),
    marketAddLiquidityFacet: await loupe.facetAddress(SELECTOR_FOR_ADD_LIQUIDITY_FACET),
    marketRemoveLiquidityFacet: await loupe.facetAddress(SELECTOR_FOR_REMOVE_LIQUIDITY_FACET),
    marketLensFacet: await loupe.facetAddress(SELECTOR_FOR_LENS_FACET),
    marketTradeOpenPositionFacet: await loupe.facetAddress(SELECTOR_FOR_OPEN_POSITION_FACET),
    marketTradeClosePositionFacet: await loupe.facetAddress(SELECTOR_FOR_CLOSE_POSITION_FACET),
    marketLiquidateFacet: await loupe.facetAddress(SELECTOR_FOR_LIQUIDATE_FACET),
    marketSettleFacet: await loupe.facetAddress(SELECTOR_FOR_SETTLE_FACET)
  }

  const diamondCut: IDiamondCut.FacetCutStruct[] = (
    await Promise.all(
      Object.keys(oldFacets).map(async (key) => {
        const oldFacet = oldFacets[key as keyof Facets]
        const newFacet = newFacets[key as keyof Facets]

        if (oldFacet == newFacet) {
          console.log('\t\tAlready updated')
          return
        } else {
          const functionSelectors = await loupe.facetFunctionSelectors(oldFacet)
          return {
            facetAddress: newFacet,
            action: 1,
            functionSelectors
          } as IDiamondCut.FacetCutStruct
        }
      })
    )
  ).filter((cut) => !!cut) as IDiamondCut.FacetCutStruct[]
  console.log('\t\tDiamondCut: ', diamondCut)

  const diamond = IDiamondCut__factory.connect(marketAddress, runner)
  await diamond.diamondCut(diamondCut, ZeroAddress, ZeroHash)
}

export default func

func.id = 'hotfix_20240228' // id required to prevent reexecution
func.tags = ['hotfix_20240228']
