import { extendEnvironment } from 'hardhat/config'
import { lazyObject } from 'hardhat/plugins'
import { Contracts } from './Contracts'
import './type-extensions'

extendEnvironment((hre) => {
  hre.c = lazyObject(() => new Contracts(hre))
})
