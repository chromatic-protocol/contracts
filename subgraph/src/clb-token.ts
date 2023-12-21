import { Address, BigInt, ethereum } from '@graphprotocol/graph-ts'
import { CLBTokenTotalSupply } from '../generated/schema'
import {
  ICLBToken,
  TransferBatch as TransferBatchEvent,
  TransferSingle as TransferSingleEvent
} from './../generated/templates/ICLBToken/ICLBToken'

export function handleTransferSingle(event: TransferSingleEvent): void {
  if (event.params.from == Address.zero() || event.params.to == Address.zero()) {
    let clbTokenContract = ICLBToken.bind(event.address)
    let amount = clbTokenContract.totalSupply(event.params.id)
    saveTotalSupply(event.address, event.params.id, amount, event.block)
  }
}

export function handleTransferBatch(event: TransferBatchEvent): void {
  if (event.params.from == Address.zero() || event.params.to == Address.zero()) {
    let clbTokenContract = ICLBToken.bind(event.address)
    let amounts = clbTokenContract.totalSupplyBatch(event.params.ids)
    for (let i = 0; i < event.params.ids.length; i++) {
      let tokenId = event.params.ids[i]
      saveTotalSupply(event.address, tokenId, amounts[i], event.block)
    }
  }
}

function saveTotalSupply(
  address: Address,
  tokenId: BigInt,
  amount: BigInt,
  block: ethereum.Block
): void {
  let id = address.toHex() + '/' + tokenId.toString() + '@' + block.number.toString()

  let entity = CLBTokenTotalSupply.load(id)
  if (entity == null) {
    entity = new CLBTokenTotalSupply(id)
    entity.token = address
    entity.tokenId = tokenId
    entity.amount = amount
    entity.blockNumber = block.number
    entity.blockTimestamp = block.timestamp
    entity.save()
  }
}
