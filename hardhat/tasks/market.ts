import {
  ChromaticMarketFactory,
  IDiamondCut,
  IDiamondCut__factory,
  IDiamondLoupe__factory
} from '@chromatic/typechain-types'
import chalk from 'chalk'
import { ContractRunner, EventLog, FunctionFragment, ZeroAddress, ZeroHash } from 'ethers'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
import { execute, findSettlementToken } from './utils'

task('market:create', 'Create new market')
  .addParam('oracleProvider', 'The deployed oracle provider address')
  .addParam('tokenAddress', 'The settlement token address or symbol')
  .setAction(
    execute(
      async (
        factory: ChromaticMarketFactory,
        taskArgs: TaskArguments,
        hre: HardhatRuntimeEnvironment
      ): Promise<any> => {
        const { deployments, getNamedAccounts, ethers } = hre
        const { deployer } = await getNamedAccounts()

        const { oracleProvider, tokenAddress } = taskArgs
        const { address: oracleProviderAddress } = await deployments.get(oracleProvider)

        if (!(await factory.isRegisteredOracleProvider(oracleProviderAddress))) {
          console.log(
            chalk.blue(
              `Not registered oracle provider [${oracleProvider}: ${oracleProviderAddress}]`
            )
          )
          return
        }

        const token = await findSettlementToken(factory, tokenAddress)
        if (!token) {
          console.log(chalk.red(`Cannot found settlement token '${tokenAddress}'`))
          return
        }

        const resp = await (
          await factory.createMarket(oracleProviderAddress, await token.getAddress())
        ).wait()

        const marketCreated = resp?.logs?.find((l) => {
          return l && (<EventLog>l).eventName == 'MarketCreated'
        }) as EventLog | undefined
        if (marketCreated) {
          const marketAddress = marketCreated.args[2]
          const runner = await ethers.getSigner(deployer)
          const { address: marketStateFacet } = await deployments.get('MarketStateFacet')
          const { address: marketAddLiquidityFacet } = await deployments.get(
            'MarketAddLiquidityFacet'
          )
          const { address: marketRemoveLiquidityFacet } = await deployments.get(
            'MarketRemoveLiquidityFacet'
          )
          const { address: marketLensFacet } = await deployments.get('MarketLensFacet')
          const { address: marketTradeOpenPositionFacet } = await deployments.get(
            'MarketTradeOpenPositionFacet'
          )
          const { address: marketTradeClosePositionFacet } = await deployments.get(
            'MarketTradeClosePositionFacet'
          )
          const { address: marketLiquidateFacet } = await deployments.get('MarketLiquidateFacet')
          const { address: marketSettleFacet } = await deployments.get('MarketSettleFacet')

          await updateFacet(
            marketAddress,
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

        console.log(
          chalk.green(
            `Success create new market [${oracleProvider}: ${oracleProviderAddress}, SettlementToken: ${await token.getAddress()}]`
          )
        )
      }
    )
  )

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
          const functionSelectors = [...(await loupe.facetFunctionSelectors(oldFacet))]
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
