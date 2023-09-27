import { reset } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { Interface, Result, TransactionReceipt } from 'ethers'
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

    await deployments.delete(contractName)
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

export type SupraPrice = {
  round: bigint
  decimal: bigint
  timestamp: bigint
  price: bigint
}

export function parseSupraPriace(bytes32: string): SupraPrice {
  if (bytes32.length > 66) {
    throw Error('overflow bytes32')
  }
  const maxBytes32 = BigInt(`0x${'FF'.repeat(32)}`)
  const bigintData = BigInt(bytes32)
  return {
    round: bigintData >> 192n,
    decimal: ((bigintData << 64n) & maxBytes32) >> 248n,
    timestamp: ((bigintData << 72n) & maxBytes32) >> 192n,
    price: ((bigintData << 136n) & maxBytes32) >> 160n
  }
}

export type EthGetLogsParam = {
  address: string
  iface: Interface
  eventName: string
  fromBlock?: number | string
  toBlock?: number | string
}

export async function mantleGetLogs(param: EthGetLogsParam): Promise<Result[]> {
  const hre = await import('hardhat')
  const realChainId = Number(await hre.getChainId())
  const chainId = realChainId === 31337 ? 5001 : realChainId
  const apiURL = hre.config.etherscan.customChains.filter((c) => c.chainId === chainId)[0].urls
    .apiURL

  const fromBlockParam = param.fromBlock ?? 0
  const toBlockParam = param.toBlock ?? 'latest'
  const topicParam = `topic0=${param.iface.getEvent(param.eventName)!.topicHash}&`
  const reqUrl = `${apiURL}?module=logs&action=getLogs&fromBlock=${fromBlockParam}&toBlock=${toBlockParam}&address=${param.address}&${topicParam}`

  console.log(reqUrl)

  const res = await fetch(reqUrl, {
    method: 'GET'
  })

  const json = await res.json()
  const logs = json.result.map((e: any) =>
    param.iface.decodeEventLog(param.eventName, e.data, e.topics)
  )

  return logs
}

export const forkingOptions = {
  arbitrum_goerli: {
    url: `https://arb-goerli.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
    blockNumber: 19474553
  },
  mantle_testnet: {
    url: `https://lb.drpc.org/ogrpc?network=mantle-testnet&dkey=${process.env.DRPC_KEY}`,
    blockNumber: 21717864
  }
}

export async function setChain(forkingOption: keyof typeof forkingOptions) {
  await reset(forkingOptions[forkingOption].url, forkingOptions[forkingOption].blockNumber)
}

export type GetEventFromTxReceiptParam = {
  receipt: TransactionReceipt
  eventName: string
  iface: Interface
}

export function getEventFromTxReceipt(param: GetEventFromTxReceiptParam) {
  const topicHash = param.iface.getEvent(param.eventName)!.topicHash.toLowerCase()
  const log = param.receipt!.logs.filter(
    (log) => log.topics.length > 0 && log.topics[0].toLowerCase() === topicHash
  )[0]
  return param.iface.decodeEventLog(param.eventName, log.data)
}
