import { Address, ethereum } from '@graphprotocol/graph-ts'
import {
  ChromaticMarketFactory,
  InterestRateRecordAppended as InterestRateRecordAppendedEvent,
  LastInterestRateRecordRemoved as LastInterestRateRecordRemovedEvent,
  MarketCreated as MarketCreatedEvent,
  OracleProviderRegistered as OracleProviderRegisteredEvent,
  SettlementTokenRegistered as SettlementTokenRegisteredEvent,
  UpdateLeverageLevel as UpdateLeverageLevelEvent,
  UpdateTakeProfitBPSRange as UpdateTakeProfitBPSRangeEvent
} from '../generated/ChromaticMarketFactory/ChromaticMarketFactory'
import { ICLBToken as ICLBToken_ } from '../generated/ChromaticMarketFactory/ICLBToken'
import { IChromaticMarket as IChromaticMarket_ } from '../generated/ChromaticMarketFactory/IChromaticMarket'
import { IERC20Metadata } from '../generated/ChromaticMarketFactory/IERC20Metadata'
import { IOracleProvider as IOracleProvider_ } from '../generated/ChromaticMarketFactory/IOracleProvider'
import {
  CLBToken,
  ChromaticMarket,
  InterestRate,
  InterestRatesSnapshot,
  MarketCreated,
  OracleProviderProperty
} from '../generated/schema'
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
  saveOracleProviderProperty(event.params.oracleProvider, event)
  IOracleProvider.create(event.params.oracleProvider)
}

export function handleUpdateLeverageLevel(event: UpdateLeverageLevelEvent): void {
  saveOracleProviderProperty(event.params.oracleProvider, event)
}

export function handleUpdateTakeProfitBPSRange(event: UpdateTakeProfitBPSRangeEvent): void {
  saveOracleProviderProperty(event.params.oracleProvider, event)
}

function saveOracleProviderProperty(oracleProvider: Address, event: ethereum.Event): void {
  let id = oracleProvider.toHex() + '@' + event.block.number.toString()
  let entity = OracleProviderProperty.load(id)
  if (entity == null) {
    let factoryContract = ChromaticMarketFactory.bind(event.address)
    let props = factoryContract.getOracleProviderProperties(oracleProvider)

    entity = new OracleProviderProperty(id)
    entity.oracleProvider = oracleProvider
    entity.minTakeProfitBPS = props.minTakeProfitBPS
    entity.maxTakeProfitBPS = props.maxTakeProfitBPS
    entity.leverageLevel = props.leverageLevel
    entity.blockNumber = event.block.number
    entity.blockTimestamp = event.block.timestamp
    entity.save()
  }
}

export function handleSettlementTokenRegistered(event: SettlementTokenRegisteredEvent): void {
  saveInterestRateRecords(event.params.token, event)
}

export function handleInterestRateRecordAppended(event: InterestRateRecordAppendedEvent): void {
  saveInterestRateRecords(event.params.token, event)
}

export function handleLastInterestRateRecordRemoved(
  event: LastInterestRateRecordRemovedEvent
): void {
  saveInterestRateRecords(event.params.token, event)
}

function saveInterestRateRecords(token: Address, event: ethereum.Event): void {
  let id = token.toHex() + '@' + event.block.number.toString()
  let entity = InterestRatesSnapshot.load(id)
  if (entity == null) {
    let factoryContract = ChromaticMarketFactory.bind(event.address)
    let records = factoryContract.getInterestRateRecords(token)

    entity = new InterestRatesSnapshot(id)
    entity.settlementToken = token
    entity.blockNumber = event.block.number
    entity.blockTimestamp = event.block.timestamp
    entity.save()

    for (let i = 0; i < records.length; i++) {
      let record = records[i]

      let recordEntity = new InterestRate(id + '/' + record.beginTimestamp.toString())
      recordEntity.annualRateBPS = record.annualRateBPS
      recordEntity.beginTimestamp = record.beginTimestamp
      recordEntity._parent = id
      recordEntity.save()
    }
  }
}
