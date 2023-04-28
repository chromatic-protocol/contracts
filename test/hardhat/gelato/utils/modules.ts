import { ethers } from 'hardhat'

/* eslint-disable @typescript-eslint/naming-convention */
export enum Module {
  RESOLVER,
  TIME,
  PROXY,
  SINGLE_EXEC
}

export type ModuleData = {
  modules: Module[]
  args: string[]
}

export const encodeResolverArgs = (resolverAddress: string, resolverData: string): string => {
  const encoded = ethers.utils.defaultAbiCoder.encode(
    ['address', 'bytes'],
    [resolverAddress, resolverData]
  )

  return encoded
}

export const decodeResolverArgs = (
  data: string
): { resolverAddress: string; resolverData: string } => {
  const result = ethers.utils.defaultAbiCoder.decode(['address', 'bytes'], data)
  return { resolverAddress: result[0], resolverData: result[1] }
}

export const decodeResolverResponse = (
  data: string
): { canExec: boolean; execPayload: string } => {
  const result = ethers.utils.defaultAbiCoder.decode(['bool', 'bytes'], data)
  return { canExec: result[0], execPayload: result[1] }
}

export const encodeTimeArgs = (startTime: number, interval: number): string => {
  const encoded = ethers.utils.defaultAbiCoder.encode(['uint128', 'uint128'], [startTime, interval])

  return encoded
}
