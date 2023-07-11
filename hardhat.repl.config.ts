import config from './hardhat.config'
import './hardhat/repl'
import util from 'util'
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
    }
  }
}
console.log('hc', util.inspect(hardhatConfig, { depth: 5 }))
export default hardhatConfig
