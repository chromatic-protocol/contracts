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
  FlashLoanExample,
  FlashLoanExample__factory,
  ICLBToken,
  ICLBToken__factory,
  IChromaticMarket,
  IChromaticMarket__factory,
  IERC20Metadata,
  IERC20Metadata__factory,
  IOracleProvider,
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

    this._signer = privateKey
      ? new Wallet(privateKey, ethers.provider)
      : (await ethers.getSigners())[0]

    this._factory = this.connectFactory(await this.addressOf('ChromaticMarketFactory'))
    this._vault = this.connectVault(await this.addressOf('ChromaticVault'))
    this._liquidator = this.connectLiquidator(await this.addressOf('ChromaticLiquidator'))
    this._router = this.connectRouter(await this.addressOf('ChromaticRouter'))
    this._lens = this.connectLens(await this.addressOf('ChromaticLens'))
    this._keeperFeePayer = this.connectKeeperFeePayer(await this.addressOf('KeeperFeePayer'))
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

  oracleProvider(address: string): IOracleProvider {
    return IOracleProvider__factory.connect(address, this._signer!)
  }

  token(address: string): IERC20Metadata {
    return IERC20Metadata__factory.connect(address, this._signer!)
  }

  clbToken(address: string): ICLBToken {
    return ICLBToken__factory.connect(address, this._signer!)
  }

  market(address: string): IChromaticMarket {
    return IChromaticMarket__factory.connect(address, this._signer!)
  }

  connectFactory(address: string): ChromaticMarketFactory {
    return ChromaticMarketFactory__factory.connect(address, this._signer)
  }

  connectVault(address: string): ChromaticVault {
    return ChromaticVault__factory.connect(address, this._signer)
  }

  connectLiquidator(address: string): ChromaticLiquidator {
    return ChromaticLiquidator__factory.connect(address, this._signer)
  }

  connectRouter(address: string): ChromaticRouter {
    return ChromaticRouter__factory.connect(address, this._signer)
  }

  connectLens(address: string): ChromaticLens {
    return ChromaticLens__factory.connect(address, this._signer)
  }

  connectKeeperFeePayer(address: string): KeeperFeePayer {
    return KeeperFeePayer__factory.connect(address, this._signer)
  }

  async getOrDeployFlashLoanExample(): Promise<FlashLoanExample> {
    const deployed = await this.hre.deployments.getOrNull('FlashLoanExample')
    return deployed
      ? this.connectFlashLoanExample(deployed.address)
      : await new FlashLoanExample__factory(this._signer).deploy(this.vault.address)
  }

  connectFlashLoanExample(address: string): FlashLoanExample {
    return FlashLoanExample__factory.connect(address, this._signer)
  }
}
