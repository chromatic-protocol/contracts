import { BigInt, ethereum } from '@graphprotocol/graph-ts'
import { ChromaticMarketBinStatus, LiquidityBinStatus } from '../generated/schema'
import {
  AddLiquidityBatch as AddLiquidityBatchEvent,
  AddLiquidity as AddLiquidityEvent,
  ClaimLiquidityBatch as ClaimLiquidityBatchEvent,
  ClaimLiquidity as ClaimLiquidityEvent,
  ClaimPositionByKeeper as ClaimPositionByKeeperEvent,
  ClaimPosition as ClaimPositionEvent,
  ClosePosition as ClosePositionEvent,
  IChromaticMarket,
  Liquidate as LiquidateEvent,
  OpenPosition as OpenPositionEvent,
  RemoveLiquidityBatch as RemoveLiquidityBatchEvent,
  RemoveLiquidity as RemoveLiquidityEvent,
  WithdrawLiquidityBatch as WithdrawLiquidityBatchEvent,
  WithdrawLiquidity as WithdrawLiquidityEvent
} from './../generated/templates/IChromaticMarket/IChromaticMarket'

export function handleAddLiquidity(event: AddLiquidityEvent): void {
  saveLiquidityBinStatus(event)
}

export function handleAddLiquidityBatch(event: AddLiquidityBatchEvent): void {
  saveLiquidityBinStatus(event)
}

export function handleClaimLiquidity(event: ClaimLiquidityEvent): void {
  saveLiquidityBinStatus(event)
}

export function handleClaimLiquidityBatch(event: ClaimLiquidityBatchEvent): void {
  saveLiquidityBinStatus(event)
}

export function handleRemoveLiquidity(event: RemoveLiquidityEvent): void {
  saveLiquidityBinStatus(event)
}

export function handleRemoveLiquidityBatch(event: RemoveLiquidityBatchEvent): void {
  saveLiquidityBinStatus(event)
}

export function handleWithdrawLiquidity(event: WithdrawLiquidityEvent): void {
  saveLiquidityBinStatus(event)
}

export function handleWithdrawLiquidityBatch(event: WithdrawLiquidityBatchEvent): void {
  saveLiquidityBinStatus(event)
}

export function handleOpenPosition(event: OpenPositionEvent): void {
  saveLiquidityBinStatus(event)
}

export function handleClosePosition(event: ClosePositionEvent): void {
  saveLiquidityBinStatus(event)
}

export function handleClaimPosition(event: ClaimPositionEvent): void {
  saveLiquidityBinStatus(event)
}

export function handleClaimPositionByKeeper(event: ClaimPositionByKeeperEvent): void {
  saveLiquidityBinStatus(event)
}

export function handleLiquidate(event: LiquidateEvent): void {
  saveLiquidityBinStatus(event)
}

function saveLiquidityBinStatus(event: ethereum.Event): void {
  let id = event.address.toHex() + '@' + event.block.number.toString()
  let entity = ChromaticMarketBinStatus.load(id)
  if (entity == null) {
    let market = IChromaticMarket.bind(event.address)
    let statuses = market.liquidityBinStatuses()

    let longLiquidity = BigInt.zero()
    let longFreeLiquidity = BigInt.zero()
    let longBinValue = BigInt.zero()
    let shortLiquidity = BigInt.zero()
    let shortFreeLiquidity = BigInt.zero()
    let shortBinValue = BigInt.zero()
    for (let i = 0; i < statuses.length; i++) {
      let status = statuses[i]
      if (status.tradingFeeRate > 0) {
        longLiquidity = longLiquidity.plus(status.liquidity)
        longFreeLiquidity = longFreeLiquidity.plus(status.freeLiquidity)
        longBinValue = longBinValue.plus(status.binValue)
      } else {
        shortLiquidity = shortLiquidity.plus(status.liquidity)
        shortFreeLiquidity = shortFreeLiquidity.plus(status.freeLiquidity)
        shortBinValue = shortBinValue.plus(status.binValue)
      }
    }

    entity = new ChromaticMarketBinStatus(id)
    entity.market = market._address
    entity.blockNumber = event.block.number
    entity.blockTimestamp = event.block.timestamp
    entity.longLiquidity = longLiquidity
    entity.longFreeLiquidity = longFreeLiquidity
    entity.longBinValue = longBinValue
    entity.shortLiquidity = shortLiquidity
    entity.shortFreeLiquidity = shortFreeLiquidity
    entity.shortBinValue = shortBinValue
    entity.save()

    for (let i = 0; i < statuses.length; i++) {
      let status = statuses[i]
      let statusEntity = new LiquidityBinStatus(id + '/' + status.tradingFeeRate.toString())
      statusEntity.liquidity = status.liquidity
      statusEntity.freeLiquidity = status.freeLiquidity
      statusEntity.binValue = status.binValue
      statusEntity.tradingFeeRate = status.tradingFeeRate
      statusEntity._parent = entity.id
      statusEntity.save()
    }
  }
}
