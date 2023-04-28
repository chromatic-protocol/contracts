import { decodeResolverArgs, decodeResolverResponse, Module } from '@usum/test/hardhat/gelato/utils'
import { hardhatErrorPrettyPrint } from '@usum/test/hardhat/utils'
import { IERC20, LibEvents, Ops } from '@usum/typechain-types'
import { BigNumber, providers, Signer } from 'ethers'
import { ethers } from 'hardhat'

export type ModuleData = [number[], string[]] & {
  modules: number[]
  args: string[]
}

interface Task {
  taskCreator: string
  execAddress: string
  execDataOrSelector: string
  moduleData: ModuleData
  feeToken: string
  taskId: string
}

export class Keeper {
  private ops: Ops
  private provider: providers.JsonRpcProvider
  private tasks: Array<Task> = []
  private onStop: () => void = () => {}

  constructor(
    ops: Ops,
    private readonly gelato: Signer,
    private readonly fee: BigNumber,
    private readonly feeToken: IERC20
  ) {
    this.ops = ops.connect(this.gelato)
    this.provider = ops.provider as providers.JsonRpcProvider
  }

  async start() {
    this.provider.pollingInterval = 100

    const opsEvents = await ethers.getContractAt('LibEvents', this.ops.address)
    this.onTaskCreated(opsEvents)
    this.onTaskCanceled(opsEvents)

    this.onStop = () => {
      opsEvents.removeAllListeners()
    }
  }

  private onTaskCreated(contract: LibEvents) {
    contract.on(contract.filters.TaskCreated(), (_0, _1, _2, _3, _4, _5, event) => {
      const task: Task = event.args
      this.tasks.push(task)
    })
  }

  private onTaskCanceled(contract: LibEvents) {
    contract.on(contract.filters.TaskCancelled(), (_0, _1, event) => {
      const taskId = event.args.taskId
      this.tasks = this.tasks.filter((t) => t.taskId != taskId)
    })
  }

  stop() {
    this.onStop()
  }

  async execute() {
    await new Promise((resolve) => setTimeout(resolve, this.provider.pollingInterval * 2))

    for (const task of this.tasks) {
      await this.executeTask(task)
    }
  }

  async executeTask(task: Task) {
    let execDataOrSelector = task.execDataOrSelector

    for (let i = 0; i < task.moduleData.modules.length; i++) {
      if (i == Module.RESOLVER) {
        const { resolverAddress, resolverData } = decodeResolverArgs(task.moduleData.args[i])

        const result = decodeResolverResponse(
          await this.provider.call({
            to: resolverAddress,
            data: resolverData
          })
        )

        if (!result.canExec) return

        execDataOrSelector = result.execPayload
        break
      }
    }

    await hardhatErrorPrettyPrint(async () => {
      await this.ops.exec(
        task.taskCreator,
        task.execAddress,
        execDataOrSelector,
        task.moduleData,
        this.fee,
        this.feeToken.address,
        // task.feeToken,
        false,
        true
      )
    })
  }
}
