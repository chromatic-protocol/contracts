import { Address, BigInt } from '@graphprotocol/graph-ts'
import {
  ClaimPosition as ClaimPositionEvent,
  ClosePosition as ClosePositionEvent,
  OpenPosition as OpenPositionEvent
} from '../generated/IChromaticAccount/IChromaticAccount'
import { ClaimedPosition, ClosedPosition, Position } from '../generated/schema'

function id(marketAddress: Address, positionId: BigInt): string {
  return marketAddress.toHex() + '/' + positionId.toString()
}

export function handleOpenPosition(event: OpenPositionEvent): void {
  let entity = new Position(id(event.params.marketAddress, event.params.positionId))
  entity.account = event.address
  entity.marketAddress = event.params.marketAddress
  entity.positionId = event.params.positionId
  entity.qty = event.params.qty
  entity.takerMargin = event.params.takerMargin
  entity.makerMargin = event.params.makerMargin
  entity.tradingFee = event.params.tradingFee
  entity.openVersion = event.params.openVersion
  entity.openTimestamp = event.params.openTimestamp

  entity.save()
}

export function handleClosePosition(event: ClosePositionEvent): void {
  let position = Position.load(id(event.params.marketAddress, event.params.positionId))
  if (position) {
    let entity = new ClosedPosition(position.id)
    entity.position = position.id
    entity.closeVersion = event.params.closeVersion
    entity.closeTimestamp = event.params.closeTimestamp

    entity.save()
  }
}

export function handleClaimPosition(event: ClaimPositionEvent): void {
  let position = Position.load(id(event.params.marketAddress, event.params.positionId))
  if (position) {
    let entity = new ClaimedPosition(position.id)
    entity.position = position.id
    entity.entryPrice = event.params.entryPrice
    entity.exitPrice = event.params.exitPrice
    entity.realizedPnl = event.params.realizedPnl
    entity.interest = event.params.interest
    entity.cause = event.params.cause.toString()
    entity.blockTimestamp = event.block.timestamp

    entity.save()
  }
}
