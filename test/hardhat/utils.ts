import { deployments, ethers, getNamedAccounts } from 'hardhat'
import { DeployOptions } from 'hardhat-deploy/types'
import util from 'util'
import { logDeployed } from './log-utils'
import { Interface, Result, TopicFilter } from 'ethers'
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'

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

export type BatchDeployParam = {
  contract: string
  signer: HardhatEthersSigner
  args: any[][]
}

export async function batchDeploy(param: BatchDeployParam) {
  const from = await param.signer.getAddress()
  const factory = await ethers.getContractFactory(param.contract, param.signer)

  const hre = await import('hardhat')
  const rpcUrl = (hre.network.config as any).url
  let id = 1

  const txParams = await Promise.all(
    param.args.map((args) => factory.getDeployTransaction(...args))
  )

  const gasRes = await fetch(rpcUrl, {
    method: 'POST',
    body: JSON.stringify(
      txParams.map((txParam) => ({
        method: 'eth_estimateGas',
        params: [txParam],
        id: id++,
        jsonrpc: '2.0'
      }))
    ),
    headers: { 'Content-Type': 'application/json' }
  })
  const gasDatas = await gasRes.json()
  const gas = gasDatas.map((g: any) => g.result)

  const body = []
  for (let i = 0; i < txParams.length; i++) {
    body.push({
      method: 'eth_sendTransaction',
      params: [{ ...txParams[i], from, gas: gas[i] }],
      id: id++,
      jsonrpc: '2.0'
    })
  }

  const txHashs = await fetch(rpcUrl, {
    method: 'POST',
    body: JSON.stringify(body),
    headers: { 'Content-Type': 'application/json' }
  })

  const txHashResults = await txHashs.json()

  // wait mining
  const lastTxHash = txHashResults[txHashResults.length - 1].result
  for (let _ = 0; _ < 15; _++) {
    await new Promise((resolve) => setTimeout(resolve, 1500))
    if (await param.signer.provider.getTransactionReceipt(lastTxHash)) {
      break
    }
  }

  const deployed = await fetch(rpcUrl, {
    method: 'POST',
    body: JSON.stringify(
      txHashResults.map((result: any) => ({
        method: 'eth_getTransactionReceipt',
        params: [result.result], // txHash
        id: id++,
        jsonrpc: '2.0'
      }))
    ),
    headers: { 'Content-Type': 'application/json' }
  })
  const receipts = await deployed.json()
  return receipts.map((r: any) => r.result.contractAddress)
}

export type BatchCallByFunctionNameParam = {
  iface: Interface
  from: string
  to: string
  functionName: string
  data: any
}

export async function batchCallByFunctionName(
  params: BatchCallByFunctionNameParam[]
): Promise<Result[]> {
  const batchCallParams = params.map((param) => ({
    from: param.from,
    to: param.to,
    data: param.iface.encodeFunctionData(param.functionName, param.data)
  }))

  const results = await batchCall(batchCallParams)

  const decodedData = []
  for (let i = 0; i < params.length; i++) {
    const param = params[i]

    decodedData.push(param.iface.decodeFunctionResult(param.functionName, results[i]))
  }
  return decodedData
}

export type BatchCallParam = {
  from: string
  to: string
  data: string
}

export async function batchCall(params: BatchCallParam[]) {
  const hre = await import('hardhat')
  const rpcUrl = (hre.network.config as any).url

  let id = 1

  const reqs = params.map((param) => ({
    method: 'eth_call',
    params: [param, 'latest'],
    id: id++,
    jsonrpc: '2.0'
  }))

  const res = await fetch(rpcUrl, {
    method: 'POST',
    body: JSON.stringify(reqs),
    headers: { 'Content-Type': 'application/json' }
  })
  const datas = await res.json()

  return datas.map((data: any) => data.result)
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
}

export async function mantleGetLogs(param: EthGetLogsParam): Promise<Result[]> {
  const hre = await import('hardhat')
  const chainId = Number(await hre.getChainId())
  const apiURL = hre.config.etherscan.customChains.filter((c) => c.chainId === chainId)[0].urls
    .apiURL

  const topicParam = `topic0=${param.iface.getEvent(param.eventName)!.topicHash}&`
  const reqUrl = `${apiURL}?module=logs&action=getLogs&fromBlock=0&toBlock=latest&address=${param.address}&${topicParam}`

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
