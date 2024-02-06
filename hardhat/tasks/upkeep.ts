import { execute } from '@chromatic/hardhat/tasks/utils'
import {
  ChromaticMarketFactory,
  ChromaticVault,
  ChromaticVault__factory,
  IChromaticMarket,
  IChromaticMarket__factory,
  IERC20Metadata__factory,
  IMate2AutomationRegistry1_1,
  IMate2AutomationRegistry1_1__factory,
  IOracleProvider__factory,
  IUpkeepTreasury,
  IUpkeepTreasury__factory,
  Mate2MarketSettlement,
  Mate2MarketSettlement__factory,
  Mate2VaultEarningDistributor,
  Mate2VaultEarningDistributor__factory
} from '@chromatic/typechain-types'
import chalk from 'chalk'
import { Table } from 'console-table-printer'
import { formatEther, parseEther } from 'ethers'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'

task('upkeep', 'List all upkeeps').setAction(async (taskArgs, hre) => {
  await hre.run('upkeep:vault:maker')
  await hre.run('upkeep:vault:market')
  await hre.run('upkeep:settlement')
})

task('upkeep:clear', 'Clear all upkeeps').setAction(async (taskArgs, hre) => {
  await hre.run('upkeep:vault:maker:clear')
  await hre.run('upkeep:vault:market:clear')
  await hre.run('upkeep:settlement:clear')
})

task('upkeep:vault:maker', 'List vault maker earning distribution upkeeps').setAction(
  execute(
    withDistributor(async (factory, ditributor, taskArgs, hre) => {
      const settlementTokens = (await factory.registeredSettlementTokens()).map((addr) =>
        IERC20Metadata__factory.connect(addr, factory.runner)
      )

      const table = new Table({
        title: 'vault maker earning distribution upkeeps',
        columns: [
          { name: 'token' },
          { name: 'token_address', title: 'token address' },
          { name: 'upkeep_id', title: 'upkeep id' }
        ],
        rows: await Promise.all(
          settlementTokens.map(async (token) => ({
            token: await token.symbol(),
            token_address: await token.getAddress(),
            upkeep_id: await ditributor.makerEarningDistributionUpkeepIds(token)
          }))
        )
      })
      table.printTable()
    })
  )
)

task('upkeep:vault:maker:clear', 'Clear vault maker earning distribution upkeeps').setAction(
  execute(
    withVault(async (factory, vault, taskArgs, hre) => {
      const settlementTokens = await factory.registeredSettlementTokens()
      for (const token of settlementTokens) {
        await vault.cancelMakerEarningDistributionTask(token)
      }
    })
  )
)

task('upkeep:vault:market', 'List vault market earning distribution upkeeps').setAction(
  execute(
    withDistributor(async (factory, ditributor, taskArgs, hre) => {
      const markets = (await factory.getMarkets()).map((addr) =>
        IChromaticMarket__factory.connect(addr, factory.runner)
      )

      const table = new Table({
        title: 'vault market earning distribution upkeeps',
        columns: [
          { name: 'market' },
          { name: 'market_address', title: 'market address' },
          { name: 'upkeep_id', title: 'upkeep id' }
        ],
        rows: await Promise.all(
          markets.map(async (market) => {
            return {
              market: await marketName(market),
              market_address: await market.getAddress(),
              upkeep_id: await ditributor.marketEarningDistributionUpkeepIds(market)
            }
          })
        )
      })
      table.printTable()
    })
  )
)

task('upkeep:vault:market:clear', 'Clear vault market earning distribution upkeeps').setAction(
  execute(
    withVault(async (factory, vault, taskArgs, hre) => {
      const markets = await factory.getMarkets()
      for (const market of markets) {
        await vault.cancelMarketEarningDistributionTask(market)
      }
      await hre.run('upkeep:settlement:withdraw')
    })
  )
)

task('upkeep:settlement', 'List market settlement upkeeps').setAction(
  execute(
    withSettlement(async (factory, settlement, taskArgs, hre) => {
      const markets = (await factory.getMarkets()).map((addr) =>
        IChromaticMarket__factory.connect(addr, factory.runner)
      )

      const table = new Table({
        title: 'vault market settlement upkeeps',
        columns: [
          { name: 'market' },
          { name: 'market_address', title: 'market address' },
          { name: 'upkeep_id', title: 'upkeep id' }
        ],
        rows: await Promise.all(
          markets.map(async (market) => {
            return {
              market: await marketName(market),
              market_address: await market.getAddress(),
              upkeep_id: await settlement.marketSettlementUpkeepIds(market)
            }
          })
        )
      })
      table.printTable()
    })
  )
)

task('upkeep:settlement:clear', 'Clear market settlement upkeeps').setAction(
  execute(
    withSettlement(async (factory, settlement, taskArgs, hre) => {
      const markets = await factory.getMarkets()
      for (const market of markets) {
        await settlement.cancelSettlementTask(market)
      }
    })
  )
)

task(
  'upkeep:settlement:balance',
  'Show the balance of keeper funds for market settlement upkeeps'
).setAction(
  execute(
    withSettlement(async (factory, settlement, taskArgs, hre) => {
      const balance = await settlement.balanceOfUpkeepTreasury()
      console.log(chalk.yellow(`Balance: ${formatEther(balance)}`))
    })
  )
)

task('upkeep:settlement:deposit', 'Deposit keeper funds for market settlement upkeeps')
  .addParam('amount', 'The keeper fund amount for market settlement upkeeps')
  .setAction(
    execute(
      withSettlement(async (factory, settlement, taskArgs, hre) => {
        const amount = parseEther(taskArgs.amount)
        const treasury = await upkeepTreasury(settlement)
        await treasury.depositFunds(settlement, { value: amount })
      })
    )
  )

task(
  'upkeep:settlement:withdraw',
  'Withdraw all keeper funds for market settlement upkeeps'
).setAction(
  execute(
    withSettlement(async (factory, settlement, taskArgs, hre) => {
      const signer = (await hre.ethers.getSigners())[0]
      const balance = await settlement.balanceOfUpkeepTreasury()
      await settlement.withdrawUpkeepTreasuryFunds(signer, balance)
    })
  )
)

async function marketName(market: IChromaticMarket): Promise<string> {
  const settlementToken = IERC20Metadata__factory.connect(
    await market.settlementToken(),
    market.runner
  )
  const oracleProvider = IOracleProvider__factory.connect(
    await market.oracleProvider(),
    market.runner
  )
  return `${await settlementToken.symbol()} - ${await oracleProvider.description()}`
}

async function automationRegistry(
  settlement: Mate2MarketSettlement
): Promise<IMate2AutomationRegistry1_1> {
  return IMate2AutomationRegistry1_1__factory.connect(
    await settlement.automate(),
    settlement.runner
  )
}

async function upkeepTreasury(settlement: Mate2MarketSettlement): Promise<IUpkeepTreasury> {
  const registry = await automationRegistry(settlement)
  return IUpkeepTreasury__factory.connect(await registry.getUpkeepTreasury(), settlement.runner)
}

function withVault(
  action: (
    factory: ChromaticMarketFactory,
    vault: ChromaticVault,
    taskArgs: TaskArguments,
    hre: HardhatRuntimeEnvironment
  ) => Promise<any>
): (
  factory: ChromaticMarketFactory,
  taskArgs: TaskArguments,
  hre: HardhatRuntimeEnvironment
) => Promise<any> {
  return async (
    factory: ChromaticMarketFactory,
    taskArgs: TaskArguments,
    hre: HardhatRuntimeEnvironment
  ): Promise<any> => {
    const vault = ChromaticVault__factory.connect(await factory.vault(), factory.runner)
    return action(factory, vault, taskArgs, hre)
  }
}

function withDistributor(
  action: (
    factory: ChromaticMarketFactory,
    ditributor: Mate2VaultEarningDistributor,
    taskArgs: TaskArguments,
    hre: HardhatRuntimeEnvironment
  ) => Promise<any>
): (
  factory: ChromaticMarketFactory,
  taskArgs: TaskArguments,
  hre: HardhatRuntimeEnvironment
) => Promise<any> {
  return withVault(
    async (
      factory: ChromaticMarketFactory,
      vault: ChromaticVault,
      taskArgs: TaskArguments,
      hre: HardhatRuntimeEnvironment
    ): Promise<any> => {
      const distributor = Mate2VaultEarningDistributor__factory.connect(
        await vault.earningDistributor(),
        factory.runner
      )

      return action(factory, distributor, taskArgs, hre)
    }
  )
}

function withSettlement(
  action: (
    factory: ChromaticMarketFactory,
    settlement: Mate2MarketSettlement,
    taskArgs: TaskArguments,
    hre: HardhatRuntimeEnvironment
  ) => Promise<any>
): (
  factory: ChromaticMarketFactory,
  taskArgs: TaskArguments,
  hre: HardhatRuntimeEnvironment
) => Promise<any> {
  return async (
    factory: ChromaticMarketFactory,
    taskArgs: TaskArguments,
    hre: HardhatRuntimeEnvironment
  ): Promise<any> => {
    const settlement = Mate2MarketSettlement__factory.connect(
      await factory.marketSettlement(),
      factory.runner
    )

    return action(factory, settlement, taskArgs, hre)
  }
}
