import { Address, BigInt } from '@graphprotocol/graph-ts'
import {
  ClosePosition as ClosePositionEvent,
  OpenPosition as OpenPositionEvent
} from '../generated/IChromaticAccount/IChromaticAccount'
import { ClosedPosition, Position } from '../generated/schema'

function id(marketAddress: Address, positionId: BigInt): string {
  return marketAddress.toHex() + '/' + positionId.toString()
}

export function handleOpenPosition(event: OpenPositionEvent): void {
  let entity = new Position(id(event.params.marketAddress, event.params.positionId))
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
