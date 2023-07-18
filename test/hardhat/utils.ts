import { deployments, ethers, getNamedAccounts } from 'hardhat'
import { DeployOptions } from 'hardhat-deploy/types'
import util from 'util'
import { logDeployed } from './log-utils'

export async function deployContract<T>(
  contractName: string,
  options?: Omit<DeployOptions, 'from'> & { from?: string }
): Promise<T> {
  return hardhatErrorPrettyPrint(async () => {
    const { deployer } = await getNamedAccounts()

    const result = await deployments.deploy(contractName, {
      from: options?.from || deployer,
      ...options
    })

    logDeployed(contractName, result.address)
    return (await ethers.getContractAt(contractName, result.address)) as T
  })
}

export async function hardhatErrorPrettyPrint<T>(method: () => Promise<T>): Promise<T> {
  try {
    return await method()
  } catch (e: any) {
    console.error(e)
    const stackTraceString = /error=(.*)(?=, code)/g.exec(e.stack)?.[1]
    if (stackTraceString == null) {
      throw e.error || e
    }
    const reason = /reason=(.*)(?=, method)/g.exec(e.message)?.[1]
    try {
      const stackObj = JSON.parse(stackTraceString)
      if (typeof stackObj === 'object') {
        stackObj.stackTrace?.forEach((element: any) => {
          if (element?.sourceReference?.sourceContent) delete element.sourceReference.sourceContent
        })
      }
      console.error(`Error: ${reason}\n`, util.inspect(stackObj, { depth: 5 }))
      console.error(e.error)
    } catch (internalError: any) {
      console.error(internalError)
    }
    throw e.error || e
  }
}
