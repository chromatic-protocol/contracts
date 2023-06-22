import { extendEnvironment } from 'hardhat/config'
import { lazyFunction } from 'hardhat/plugins'
import {
  ChromaticLens__factory,
  ChromaticLiquidator__factory,
  ChromaticMarketFactory__factory,
  ChromaticRouter__factory,
  ChromaticVault__factory,
  KeeperFeePayer__factory
} from '../../typechain-types'
import './type-extensions'

extendEnvironment((hre) => {
  const { deployments, ethers } = hre

  const addressOf = async (name: string): Promise<string> => {
    return (await deployments.get(name)).address
  }

  hre.c = {
    factory: undefined,
    vault: undefined,
    liquidator: undefined,
    router: undefined,
    lens: undefined,
    keeperFeePayer: undefined
  }

  hre.initialize = lazyFunction(() => async () => {
    const signer = (await ethers.getSigners())[0]

    const c = await Promise.resolve(hre.c)
    c.factory = ChromaticMarketFactory__factory.connect(
      await addressOf('ChromaticMarketFactory'),
      signer
    )
    c.vault = ChromaticVault__factory.connect(await addressOf('ChromaticVault'), signer)
    c.liquidator = ChromaticLiquidator__factory.connect(
      await addressOf('ChromaticLiquidator'),
      signer
    )
    c.router = ChromaticRouter__factory.connect(await addressOf('ChromaticRouter'), signer)
    c.lens = ChromaticLens__factory.connect(await addressOf('ChromaticLens'), signer)
    c.keeperFeePayer = KeeperFeePayer__factory.connect(await addressOf('KeeperFeePayer'), signer)
  })
})
