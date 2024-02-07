import { Address, BigInt, dataSource, ethereum } from '@graphprotocol/graph-ts'
import { OracleVersion } from '../generated/schema'
import { IOracleProvider } from '../generated/templates/IOracleProvider/IOracleProvider'
import { IOracleProviderPullBased } from '../generated/templates/IOracleProvider/IOracleProviderPullBased'

export function saveOracleVersion(block: ethereum.Block): void {
  let context = dataSource.context()
  let pullBased = context.getBoolean('IOracleProviderPullBased')

  if (pullBased) {
    let oracleProvider = IOracleProviderPullBased.bind(dataSource.address())
    let oracleVersion = oracleProvider.lastSyncedVersion()
    _saveOracleVersion(
      block,
      oracleProvider._address,
      oracleVersion.version,
      oracleVersion.timestamp,
      oracleVersion.price
    )
  } else {
    let oracleProvider = IOracleProvider.bind(dataSource.address())
    let oracleVersion = oracleProvider.currentVersion()
    _saveOracleVersion(
      block,
      oracleProvider._address,
      oracleVersion.version,
      oracleVersion.timestamp,
      oracleVersion.price
    )
  }
}

function _saveOracleVersion(
  block: ethereum.Block,
  address: Address,
  version: BigInt,
  timestamp: BigInt,
  price: BigInt
): void {
  let id = address.toHex() + '/' + version.toString()
  let entity = OracleVersion.load(id)
  if (entity == null) {
    entity = new OracleVersion(id)
    entity.oracleProvider = address
    entity.version = version
    entity.timestamp = timestamp
    entity.price = price
    entity.blockNumber = block.number
    entity.blockTimestamp = block.timestamp
    entity.save()
  }
}
