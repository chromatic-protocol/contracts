import { Address } from '@graphprotocol/graph-ts'
import {
  MarketCreated as MarketCreatedEvent,
  OracleProviderRegistered as OracleProviderRegisteredEvent
} from '../generated/ChromaticMarketFactory/ChromaticMarketFactory'
import { IERC20Metadata } from '../generated/ChromaticMarketFactory/IERC20Metadata'
import { IOracleProvider as IOracleProvider_ } from '../generated/ChromaticMarketFactory/IOracleProvider'
import { ChromaticMarket, MarketCreated } from '../generated/schema'
import { IChromaticMarket, IOracleProvider } from '../generated/templates'

export function handleMarketCreated(event: MarketCreatedEvent): void {
  let entity = new MarketCreated(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.oracleProvider = event.params.oracleProvider
  entity.settlementToken = event.params.settlementToken
  entity.market = event.params.market

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()

  let marketEntity = ChromaticMarket.load(entity.market)
  if (marketEntity == null) {
    let tokenContract = IERC20Metadata.bind(Address.fromBytes(entity.settlementToken))
    let providerContract = IOracleProvider_.bind(Address.fromBytes(entity.oracleProvider))

    marketEntity = new ChromaticMarket(entity.market)
    marketEntity.settlementToken = tokenContract._address
    marketEntity.settlementTokenSymbol = tokenContract.symbol()
    marketEntity.settlementTokenDecimals = tokenContract.decimals()
    marketEntity.oracleProvider = providerContract._address
    marketEntity.oracleDescription = providerContract.description()

    marketEntity.save()
  }

  IChromaticMarket.create(event.params.market)
}

export function handleOracleProviderRegistered(event: OracleProviderRegisteredEvent): void {
  IOracleProvider.create(event.params.oracleProvider)
}
