import { Address } from '@graphprotocol/graph-ts'
import {
  MarketCreated as MarketCreatedEvent,
  OracleProviderRegistered as OracleProviderRegisteredEvent
} from '../generated/ChromaticMarketFactory/ChromaticMarketFactory'
import { ICLBToken as ICLBToken_ } from '../generated/ChromaticMarketFactory/ICLBToken'
import { IChromaticMarket as IChromaticMarket_ } from '../generated/ChromaticMarketFactory/IChromaticMarket'
import { IERC20Metadata } from '../generated/ChromaticMarketFactory/IERC20Metadata'
import { IOracleProvider as IOracleProvider_ } from '../generated/ChromaticMarketFactory/IOracleProvider'
import { ChromaticMarket, MarketCreated, CLBToken } from '../generated/schema'
import { ICLBToken, IChromaticMarket, IOracleProvider } from '../generated/templates'

export function handleMarketCreated(event: MarketCreatedEvent): void {
  let entity = new MarketCreated(event.transaction.hash.concatI32(event.logIndex.toI32()))
  entity.oracleProvider = event.params.oracleProvider
  entity.settlementToken = event.params.settlementToken
  entity.market = event.params.market

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()

  let marketContract = IChromaticMarket_.bind(Address.fromBytes(entity.market))

  let marketEntity = ChromaticMarket.load(marketContract._address)
  if (marketEntity == null) {
    let tokenContract = IERC20Metadata.bind(Address.fromBytes(entity.settlementToken))
    let providerContract = IOracleProvider_.bind(Address.fromBytes(entity.oracleProvider))

    marketEntity = new ChromaticMarket(marketContract._address)
    marketEntity.settlementToken = tokenContract._address
    marketEntity.settlementTokenSymbol = tokenContract.symbol()
    marketEntity.settlementTokenDecimals = tokenContract.decimals()
    marketEntity.oracleProvider = providerContract._address
    marketEntity.oracleDescription = providerContract.description()

    marketEntity.save()
  }

  IChromaticMarket.create(event.params.market)

  let clbTokenContract = ICLBToken_.bind(marketContract.clbToken())

  let clbTokenEntity = CLBToken.load(clbTokenContract._address)
  if (clbTokenEntity == null) {
    clbTokenEntity = new CLBToken(clbTokenContract._address)
    clbTokenEntity.market = marketContract._address
    clbTokenEntity.decimals = clbTokenContract.decimals()
    
    clbTokenEntity.save()
  }

  ICLBToken.create(clbTokenContract._address)
}

export function handleOracleProviderRegistered(event: OracleProviderRegisteredEvent): void {
  IOracleProvider.create(event.params.oracleProvider)
}
