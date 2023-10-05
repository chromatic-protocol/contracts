import util from 'util'
import config from './hardhat.config'
import './hardhat/repl'
const MNEMONIC_JUNK = 'test test test test test test test test test test test junk'
const hardhatConfig = {
  ...config,
  networks: {
    ...config.networks,
    anvil: {
      // localhost anvil
      ...config.networks?.anvil,
      accounts: {
        mnemonic: process.env.MNEMONIC || MNEMONIC_JUNK
      }
    },
    anvil_mantle: {
      // localhost anvil_mantle
      ...config.networks?.anvil_mantle,
      accounts: {
        mnemonic: process.env.MNEMONIC || MNEMONIC_JUNK
      }
    }
  }
}
console.log('hc', util.inspect(hardhatConfig, { depth: 5 }))
export default hardhatConfig
