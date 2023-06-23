import { Signer, Wallet } from 'ethers'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import {
  ChromaticLens,
  ChromaticLens__factory,
  ChromaticLiquidator,
  ChromaticLiquidator__factory,
  ChromaticMarketFactory,
  ChromaticMarketFactory__factory,
  ChromaticRouter,
  ChromaticRouter__factory,
  ChromaticVault,
  ChromaticVault__factory,
  ICLBToken__factory,
  IChromaticMarket__factory,
  IERC20Metadata__factory,
  IOracleProvider__factory,
  KeeperFeePayer,
  KeeperFeePayer__factory
} from '../../typechain-types'

export class Contracts {
  private _signer: Signer
  private _factory: ChromaticMarketFactory
  private _vault: ChromaticVault
  private _liquidator: ChromaticLiquidator
  private _router: ChromaticRouter
  private _lens: ChromaticLens
  private _keeperFeePayer: KeeperFeePayer

  constructor(public readonly hre: HardhatRuntimeEnvironment) {}

  async connect(privateKey: string | undefined) {
    const { ethers } = this.hre

    const signer = privateKey
      ? new Wallet(privateKey, ethers.provider)
      : (await ethers.getSigners())[0]

    this._signer = signer
    this._factory = ChromaticMarketFactory__factory.connect(
      await this.addressOf('ChromaticMarketFactory'),
      signer
    )
    this._vault = ChromaticVault__factory.connect(await this.addressOf('ChromaticVault'), signer)
    this._liquidator = ChromaticLiquidator__factory.connect(
      await this.addressOf('ChromaticLiquidator'),
      signer
    )
    this._router = ChromaticRouter__factory.connect(await this.addressOf('ChromaticRouter'), signer)
    this._lens = ChromaticLens__factory.connect(await this.addressOf('ChromaticLens'), signer)
    this._keeperFeePayer = KeeperFeePayer__factory.connect(
      await this.addressOf('KeeperFeePayer'),
      signer
    )
  }

  private async addressOf(name: string): Promise<string> {
    return (await this.hre.deployments.get(name)).address
  }

  get signer(): Signer {
    return this._signer
  }

  get factory(): ChromaticMarketFactory {
    return this._factory
  }

  get vault(): ChromaticVault {
    return this._vault
  }

  get liquidator(): ChromaticLiquidator {
    return this._liquidator
  }

  get router(): ChromaticRouter {
    return this._router
  }

  get lens(): ChromaticLens {
    return this._lens
  }

  get keeperFeePayer(): KeeperFeePayer {
    return this._keeperFeePayer
  }

  oracleProvider(address: string) {
    return IOracleProvider__factory.connect(address, this._signer!)
  }

  token(address: string) {
    return IERC20Metadata__factory.connect(address, this._signer!)
  }

  clbToken(address: string) {
    return ICLBToken__factory.connect(address, this._signer!)
  }

  market(address: string) {
    return IChromaticMarket__factory.connect(address, this._signer!)
  }
}
