import {
  AccountCreated as AccountCreatedEvent,
  OpenPosition as OpenPositionEvent
} from "../generated/ChromaticRouter/ChromaticRouter"
import { AccountCreated, OpenPosition } from "../generated/schema"

export function handleAccountCreated(event: AccountCreatedEvent): void {
  let entity = new AccountCreated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.account = event.params.account
  entity.owner = event.params.owner

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleOpenPosition(event: OpenPositionEvent): void {
  let entity = new OpenPosition(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.marketAddress = event.params.marketAddress
  entity.trader = event.params.trader
  entity.account = event.params.account
  entity.tradingFee = event.params.tradingFee
  entity.tradingFeeUSD = event.params.tradingFeeUSD

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
