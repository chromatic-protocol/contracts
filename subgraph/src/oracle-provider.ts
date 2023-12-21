import { dataSource, ethereum } from '@graphprotocol/graph-ts'
import { OracleVersion } from '../generated/schema'
import { IOracleProvider } from '../generated/templates/IOracleProvider/IOracleProvider'

export function saveOracleVersion(block: ethereum.Block): void {
  let oracleProvider = IOracleProvider.bind(dataSource.address())
  let oracleVersion = oracleProvider.currentVersion()

  let id = oracleProvider._address.toHex() + '/' + oracleVersion.version.toString()
  let entity = OracleVersion.load(id)
  if (entity == null) {
    entity = new OracleVersion(id)
    entity.oracleProvider = oracleProvider._address
    entity.version = oracleVersion.version
    entity.timestamp = oracleVersion.timestamp
    entity.price = oracleVersion.price
    entity.blockNumber = block.number
    entity.blockTimestamp = block.timestamp
    entity.save()
  }
}
