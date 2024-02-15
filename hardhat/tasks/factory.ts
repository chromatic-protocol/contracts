import { ChromaticMarketFactory } from '@chromatic/typechain-types'
import chalk from 'chalk'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment, TaskArguments } from 'hardhat/types'
import { execute } from './utils'

task('factory:set', 'Update factory properties')
  .addOptionalParam('treasuryAddress', 'The DAO treasury address')
  .setAction(
    execute(
      async (
        factory: ChromaticMarketFactory,
        taskArgs: TaskArguments,
        hre: HardhatRuntimeEnvironment
      ): Promise<any> => {
        if (taskArgs.treasuryAddress) {
          await factory.updateTreasury(taskArgs.treasuryAddress)
          console.log(chalk.green('DAO treasury is updated'))
        }
      }
    )
  )
